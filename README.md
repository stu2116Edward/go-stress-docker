# go-stress-docker

## 介绍
go-stress-testing 是go语言实现的简单压测工具，源码开源、支持二次开发，可以压测http、webSocket请求、私有rpc调用，使用协程模拟单个用户，可以更高效的利用CPU资源。  

项目地址：https://github.com/link1st/go-stress-testing

## 用法

### 使用示例:  

#### 使用请求百度页面
```
docker run --rm stu2116edwardhu/go-stress:latest \
  -c 1 -n 100 -u https://www.baidu.com/
```

#### 使用debug模式请求百度页面
```
docker run --rm stu2116edwardhu/go-stress:latest \
  -c 1 -n 1 -d true -u https://www.baidu.com/
```

#### 使用 curl文件进行压测
curl是Linux在命令行下的工作的文件传输工具，是一款很强大的http命令行工具。  

使用curl文件可以压测使用非GET的请求，支持设置http请求的 `method`、`cookies`、`header`、`body`等参数  

I: chrome 浏览器生成 curl文件，打开开发者模式(快捷键F12)，如图所示，生成 curl 在终端执行命令  
<img width="810" height="542" alt="copy cURL" src="https://github.com/user-attachments/assets/49082fd9-ae5c-4b16-baf6-8543bd9a5ed1" />  

II: postman 生成 curl 命令  
<img width="1141" height="850" alt="postman cURL" src="https://github.com/user-attachments/assets/98edd8f0-1af4-4883-b7ae-ec5405297dba" />  

生成内容粘贴到项目目录下的`test.curl.txt`文件中，执行下面命令就可以从curl.txt文件中读取需要压测的内容进行压测了  
例如 `test.curl.txt`  
```
curl 'https://api.example.com/test' \
  -H 'authority: api.example.com' \
  -H 'accept: application/json' \
  -H 'content-type: application/json' \
  --data-raw '{"test":"data"}'
```
执行压测
```
docker run --rm \
  -v $(pwd)/test.curl.txt:/app/test.curl.txt \
  stu2116edwardhu/go-stress:latest \
  -c 5 -n 20 -p /app/test.curl.txt
```

上传二进制文件（图片、PDF等）
```
cat > curl/upload_binary.curl.txt << 'EOF'
curl -X POST http://localhost:8088/upload \
  -H "Content-Type: application/octet-stream" \
  --data-binary @test.bin
EOF
```
从文件读取表单数据
```
cat > curl/upload_data.curl.txt << 'EOF'
curl -X POST http://localhost:8088/api/user \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data @data.txt
EOF
```
执行文件上传压测  
上传二进制文件压测
```
docker run --rm \
  -v $(pwd)/test.bin:/app/test.bin \
  -v $(pwd)/curl/upload_binary.curl.txt:/app/upload_binary.curl.txt \
  stu2116edwardhu/go-stress:latest \
  -c 10 -n 100 -p /app/upload_binary.curl.txt
```
上传表单数据压测
```
docker run --rm \
  -v $(pwd)/data.txt:/app/data.txt \
  -v $(pwd)/curl/upload_data.curl.txt:/app/upload_data.curl.txt \
  stu2116edwardhu/go-stress:latest \
  -c 10 -n 100 -p /app/upload_data.curl.txt
```

#### 压测webSocket连接
```
docker run --rm stu2116edwardhu/go-stress:latest \
  -c 10 -n 10 \
  -u ws://localhost:8080/ws-endpoint
```

#### 完整压测命令示例：  
更多参数 支持 `header`、`post body`
```
docker run --rm stu2116edwardhu/go-stress:latest \
  -c 1 \
  -n 1 \
  -d true \
  -u 'https://page.aliyun.com/delivery/plan/list' \
  -H 'authority: page.aliyun.com' \
  -H 'accept: application/json, text/plain, */*' \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H 'origin: https://cn.aliyun.com' \
  -H 'sec-fetch-site: same-site' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-dest: empty' \
  -H 'referer: https://cn.aliyun.com/' \
  -H 'accept-language: zh-CN,zh;q=0.9' \
  -H 'cookie: aliyun_choice=CN; JSESSIONID=J8866281-CKCFJ4BUZ7GDO9V89YBW1-KJ3J5V9K-GYUW7; maliyun_temporary_console0=1AbLByOMHeZe3G41KYd5WWZvrM%2BGErkaLcWfBbgveKA9ifboArprPASvFUUfhwHtt44qsDwVqMk8Wkdr1F5LccYk2mPCZJiXb0q%2Bllj5u3SQGQurtyPqnG489y%2FkoA%2FEvOwsXJTvXTFQPK%2BGJD4FJg%3D%3D; cna=L3Q5F8cHDGgCAXL3r8fEZtdU; isg=BFNThsmSCcgX-sUcc5Jo2s2T4tF9COfKYi8g9wVwr3KphHMmjdh3GrHFvPTqJD_C; l=eBaceXLnQGBjstRJBOfwPurza77OSIRAguPzaNbMiT5POw1B5WAlWZbqyNY6C3GVh6lwR37EODnaBeYBc3K-nxvOu9eFfGMmn' \
  -data 'adPlanQueryParam=%7B%22adZone%22%3A%7B%22positionList%22%3A%5B%7B%22positionId%22%3A83%7D%5D%7D%2C%22requestId%22%3A%2217958651-f205-44c7-ad5d-f8af92a6217a%22%7D'
```

#### grpc压测
启动Server  
进入 `grpc server` 目录  
```
cd tests/grpc
```
启动 `grpc server`  
```
go run main.go
```
对 grpc server 协议进行压测
```
执行压测
```
docker run --rm --network=host stu2116edwardhu/go-stress:latest \
  -c 300 -n 1000 \
  -u grpc://127.0.0.1:8099 \
  -data 'world'
```
开始启动  并发数:300 请求数:1000 请求参数:
request:
 form:grpc
 url:grpc://127.0.0.1:8099
 method:POST
 headers:map[Content-Type:application/x-www-form-urlencoded; charset=utf-8]
 data:world
 verify:
 timeout:30s
 debug:false

─────┬───────┬───────┬───────┬────────┬────────┬────────┬────────┬────────┬────────┬────────
 耗时 │ 并发数 │ 成功数 │ 失败数 │   qps  │最长耗时  │最短耗时 │平均耗时  │下载字节 │字节每秒  │ 错误码
─────┼───────┼───────┼───────┼────────┼────────┼────────┼────────┼────────┼────────┼────────
   1s│    186│  14086│      0│34177.69│   22.40│    0.63│    8.78│        │        │200:14086
   2s│    265│  30408│      0│26005.09│   32.68│    0.63│   11.54│        │        │200:30408
   3s│    300│  46747│      0│21890.46│   40.84│    0.63│   13.70│        │        │200:46747
   4s│    300│  62837│      0│20057.06│   45.81│    0.63│   14.96│        │        │200:62837
   5s│    300│  79119│      0│19134.52│   45.81│    0.63│   15.68│        │        │200:79119
```

#### 查看用法
```
docker run --rm stu2116edwardhu/go-stress:latest --help
```
支持参数：
<pre>
Usage of ./go-stress-testing-mac:
  -c uint
      并发数 (default 1)
  -n uint
      请求数(单个并发/协程) (default 1)
  -u string
      压测地址
  -d string
      调试模式 (default "false")
  -http2
    	是否开http2.0
  -k	是否开启长连接
  -m int
    	单个host最大连接数 (default 1)
  -H value
      自定义头信息传递给服务器 示例:-H 'Content-Type: application/json'
  -data string
      HTTP POST方式传送数据
  -v string
      验证方法 http 支持:statusCode、json webSocket支持:json
  -p string
      curl文件路径
</pre>
`-n` 是单个用户请求的次数，请求总次数 = `-c`* `-n`， 这里考虑的是模拟用户行为，所以这个是每个用户请求的次数  


### 使用技巧

#### 保存输出到文件
```
docker run --rm stu2116edwardhu/go-stress:latest \
  -c 5 -n 100 -u https://www.baidu.com/ \
  > stress-test-results.log
```
#### 资源限制运行
限制CPU和内存使用
```
docker run --rm \
  --cpus="1.0" \
  --memory="512m" \
  stu2116edwardhu/go-stress:latest \
  -c 50 -n 200 -u https://www.example.com/
```

### 压测过程中查看系统状态
在一个终端运行压测
```
docker run --rm --name go-stress-test \
  stu2116edwardhu/go-stress:latest \
  -c 100 -n 1000 -u https://www.example.com/
```
在另一个终端监控
```
docker stats go-stress-test
```
