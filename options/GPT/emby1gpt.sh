#!/bin/bash

echo "如果输入 '1'，则安装作者手搓版本；"
echo "如果输入 '2'，则安装GPT优化版本（暂时未经测试，可能存在未知错误）。"
read input

if [ "$input" == "1" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/separate/emby1sep.sh && chmod +x emby1sep.sh && ./emby1sep.sh
elif [ "$input" == "2" ]; then
    wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/sh/separate/gpt/gptemby1.sh && chmod +x emby1gpt.sh && ./emby1gpt.sh
else
    echo "无效输入，请输入 '1' 或 '2' "
fi
