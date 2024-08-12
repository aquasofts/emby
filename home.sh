#!/bin/bash

echo "如果输入 '1'，则安装 http 协议；"
echo "如果输入 '2'，则安装 https 协议(需要提前准备好域名证书)"
echo "如果输入 '3'，则安装 https 协议(自动申请域名证书)"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/emby.sh && chmod +x emby.sh && ./emby.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/emby2.sh && chmod +x emby2.sh && ./emby2.sh
elif [ "$input" == "3" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/emby3.sh && chmod +x emby3.sh && ./emby3.sh
else
    echo "无效输入，请输入 '1' 或 '2' 或 '2'"
fi
