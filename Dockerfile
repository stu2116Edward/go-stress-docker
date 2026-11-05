# 构建阶段 - 使用完整的构建环境
# FROM golang:1.21-alpine AS builder
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

WORKDIR /app

# 支持 BuildKit 多架构构建
ARG BUILDPLATFORM
ARG BUILDARCH
ARG TARGETOS=linux
ARG TARGETARCH
ARG TARGETPLATFORM

# 支持指定 go-stress 源码版本或 Commit SHA
# 正式发布建议指定固定 Commit，保证构建可重复
ARG GO_STRESS_REF=master

# 控制是否启用 UPX 压缩
ARG ENABLE_UPX=1

# 安装构建依赖（包括strip工具）
# 使用纯 Go 编译，不需要 gcc、g++、musl-dev
# 保留 git 用于直接下载和构建 go-stress（无需本地源代码）
RUN set -eux && \
    apk add --no-cache \
    git \
    binutils \
    upx \
    file \
    ca-certificates \
    && update-ca-certificates

# 直接下载并构建 go-stress（无需本地源代码）
# 使用 Git Commit 参数提高构建可重复性
RUN set -eux && \
    git init . && \
    git remote add origin https://github.com/link1st/go-stress-testing.git && \
    git fetch --depth 1 origin "${GO_STRESS_REF}" && \
    git checkout --detach FETCH_HEAD

# 检查 Go 版本和目标架构
RUN set -eux && \
    go version && \
    echo "Build platform: ${BUILDPLATFORM}" && \
    echo "Build architecture: ${BUILDARCH}" && \
    echo "Target platform: ${TARGETPLATFORM}" && \
    echo "Target architecture: ${TARGETARCH}"

# Go Modules 缓存
# 使用 BuildKit 缓存减少重复下载依赖
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# 创建输出目录及运行时必要文件
RUN set -eux && \
    mkdir -p /out /runtime/etc /runtime/tmp && \
    printf 'app:x:65532:65532:app:/nonexistent:/sbin/nologin\n' > /runtime/etc/passwd && \
    printf 'app:x:65532:\n' > /runtime/etc/group && \
    chmod 1777 /runtime/tmp

# 构建静态二进制文件
# 使用纯 Go 编译，避免动态链接 musl libc
# 使用原生构建平台编译目标架构，避免 QEMU 编译开销
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux && \
    CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    go build \
    -tags extended,netgo,osusergo \
    -trimpath \
    -buildvcs=false \
    -ldflags="-s -w -buildid=" \
    -o /out/go-stress \
    . && \
    chmod 755 /out/go-stress

# 检查构建后的文件
RUN set -eux && \
    echo "Binary information:" && \
    file /out/go-stress && \
    echo "Binary size after build:" && \
    du -h /out/go-stress && \
    du -b /out/go-stress

# 使用strip进一步减小二进制文件大小
# 注意：-ldflags="-s -w" 已经去除大部分调试信息
RUN set -eux && \
    strip --strip-all /out/go-stress || true && \
    echo "Binary size after stripping:" && \
    du -h /out/go-stress && \
    du -b /out/go-stress

# UPX 压缩，压缩失败时保留原始可执行文件
# 使用 UPX 测试压缩结果，避免仅凭退出状态判断压缩成功
RUN set -eux && \
    if [ "${ENABLE_UPX}" = "1" ]; then \
        cp /out/go-stress /out/go-stress.uncompressed; \
        if upx --best --lzma /out/go-stress && upx -t /out/go-stress; then \
            echo "UPX compression successful"; \
        else \
            echo "UPX compression failed, restoring original binary"; \
            cp /out/go-stress.uncompressed /out/go-stress; \
        fi; \
        rm -f /out/go-stress.uncompressed; \
    else \
        echo "UPX compression disabled"; \
    fi && \
    echo "Binary size after UPX:" && \
    du -h /out/go-stress && \
    du -b /out/go-stress && \
    file /out/go-stress

# 检查最终二进制架构
RUN set -eux && \
    case "${TARGETARCH}" in \
        amd64) EXPECTED_ARCH="Advanced Micro Devices X86-64" ;; \
        arm64) EXPECTED_ARCH="AArch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    readelf -h /out/go-stress | grep -F "${EXPECTED_ARCH}" && \
    echo "Checking static binary..." && \
    if readelf -l /out/go-stress | grep -q INTERP; then \
        echo "ERROR: Dynamic interpreter detected"; \
        exit 1; \
    else \
        echo "Static ELF verification passed"; \
    fi

# 运行时阶段（极小的基础镜像，包含基本shell）
# FROM busybox:musl
# FROM alpine:latest
FROM scratch AS pod
# FROM hectorm/scratch:latest AS pod

# 复制CA证书（用于HTTPS请求）
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制运行时用户信息
COPY --from=builder /runtime/etc/passwd /etc/passwd
COPY --from=builder /runtime/etc/group /etc/group

# 创建临时目录（支持需要临时文件的程序）
COPY --from=builder --chown=65532:65532 --chmod=1777 /runtime/tmp /tmp

# 复制go-stress二进制文件
COPY --from=builder --chown=65532:65532 /out/go-stress /go-stress

# 创建非root用户（增强安全性）
# RUN adduser -D -u 1000 gowrk
USER 65532:65532

# 设置工作目录
# WORKDIR /app

# 切换到非root用户
# USER gowrk

# Go 运行时优化：垃圾回收器（GC）调优
# GOGC 环境变量控制GC的频率。默认值是100，表示当堆大小翻倍时触发GC。
# 在内存充足的环境中，增大此值（例如 GOGC=200）可以减少GC的运行频率，
# 从而可能提升程序性能，但代价是消耗更多的内存。
# 您可以在 `docker run` 时通过 `-e GOGC=200` 来覆盖此默认设置。
# ENV GOGC=100

# 设置入口点
ENTRYPOINT ["/go-stress"]
