#!/bin/bash


# 读取参数
METHOD=$1
ENDPOINT=$2
DATA=$3

# 根据请求类型决定是否发送数据
if [ "$METHOD" = "GET" ]; then
    # GET请求，不发送数据
    curl -X "$METHOD" -H "Authorization: Bearer 114514" http://localhost:2519/nbgui/v1/$ENDPOINT
else
    # POST或其他请求，发送数据
    curl -X "$METHOD" -H "Content-Type: application/json" -H "Authorization: Bearer 114514" -d "$DATA" http://localhost:2519/nbgui/v1/$ENDPOINT
fi
