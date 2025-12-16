
# Hugo Static Compilation Docker Build with BusyBox
# 使用 busybox:musl 作为基础镜像，提供基本shell环境

# 构建阶段 - 使用完整的构建环境
# FROM golang:1.21-alpine AS builder
FROM golang:alpine AS builder

WORKDIR /app

# 安装构建依赖（包括C++编译器和strip工具）
# 使用--no-scripts禁用触发器执行，避免busybox触发器在arm64架构下的兼容性问题
RUN set -eux && \
    FILENAME=go-stress \
    && apk add --no-cache --no-scripts --virtual .build-deps \
    gcc \
    g++ \
    musl-dev \
    git \
    build-base \
    # 包含strip命令
    binutils \
    upx \
    # 直接下载并构建 go-stress（无需本地源代码）
    && git clone --depth 1 https://github.com/link1st/go-stress-testing . \
    # 构建静态二进制文件
    # && CGO_ENABLED=1 go build \
    && CGO_ENABLED=1 go build \
    -tags extended,netgo,osusergo \
    -ldflags="-s -w -extldflags -static" \
    # -ldflags="-s -w" \
    -o go-stress \
    # 显示构建后的文件大小
    && echo "Binary size after build:" \
    # && du -h go-stress \
    && du -b go-stress \
    # 使用strip进一步减小二进制文件大小
    && strip --strip-all go-stress \
    && echo "Binary size after stripping:" \
    # && du -h go-stress \
    && du -b go-stress \
    && upx --best --lzma go-stress \
    && echo "Binary size after upx:" \
    # && du -h go-stress \
    && du -b go-stress
    # 注意：这里故意不清理构建依赖，因为是多阶段构建，且清理会触发busybox触发器错误
    # 最终镜像只复制二进制文件，构建阶段的中间层不会影响最终镜像大小
    # # 清理构建依赖
    # && apk del --purge .build-deps \
    # && rm -rf /var/cache/apk/*

# 运行时阶段 - 使用busybox:musl（极小的基础镜像，包含基本shell）
# FROM busybox:musl
# FROM alpine:latest
FROM scratch AS pod
# FROM hectorm/scratch:latest AS pod


# 复制CA证书（用于HTTPS请求）
# COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制go-stress二进制文件
COPY --from=builder /app/go-stress /go-stress

# 创建非root用户（增强安全性）
# RUN adduser -D -u 1000 gowrk

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
