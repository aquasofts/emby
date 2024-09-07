#!/bin/bash

echo "如果输入 '1'，则安装emby源服务器前后端一体版本；"
echo "如果输入 '2'，则安装emby源服务器前后端分离版本。"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/emby2.sh && chmod +x emby2.sh && ./emby2.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/options/GPT/emby2gpt.sh && chmod +x emby2gpt.sh && ./emby2gpt.sh
else
    echo "无效输入，请输入 '1' 或 '2' "
fi