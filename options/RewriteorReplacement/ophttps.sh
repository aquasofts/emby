#!/bin/bash

echo "如果输入 '1'，则安装链接重写版本；"
echo "如果输入 '2'，则安装则安装链接重写+字符替换版本。"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/Rewrite/https.sh && chmod +x https.sh && ./https.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/separate/emby2sep.sh && chmod +x emby2sep.sh && ./emby2sep.sh
else
    echo "无效输入，请输入 '1' 或 '2' "
fi
