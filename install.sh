#!/bin/bash

echo "如果输入 '1'，则安装 http 协议；"
echo "如果输入 '2'，则安装 https 协议(需要提前准备好域名证书)"
echo "如果输入 '3'，则安装 https 协议(安装过程中将会自动申请证书)"
echo "如果输入 '4'，则安装 https 协议(emby服务器含有推流地址选这个)(安装过程中将会自动申请证书)"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/emby.sh && chmod +x emby.sh && ./emby.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/emby2.sh && chmod +x emby2.sh && ./emby2.sh
elif [ "$input" == "3" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/emby3.sh && chmod +x emby3.sh && ./emby3.sh
 elif [ "$input" == "4" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/emby5.sh && chmod +x emby5.sh && ./emby5.sh
else
    echo "无效输入，请输入 '1' 或 '2' 或 '3'"
fi
