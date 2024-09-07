#!/bin/bash

echo "如果输入 '1'，则安装 http 协议；"
echo "如果输入 '2'，则安装 https 协议(需要提前准备好域名证书)"
echo "如果输入 '3'，则安装 https 协议(安装过程中将会自动申请证书)"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/options/emby1option.sh && chmod +x emby1option.sh && ./emby1option.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/options/emby2option.sh && chmod +x emby2option.sh && ./emby2option.sh
elif [ "$input" == "3" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/options/emby3option.sh && chmod +x emby3option.sh && ./emby3option.sh
else
    echo "无效输入，请输入 '1' 或 '2' 或 '3'"
fi
