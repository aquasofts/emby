#!/bin/bash

#清除环境
apt --fix-broken install

# 检查并安装nginx
if command -v nginx >/dev/null 2>&1; then
    echo "nginx已安装"
else
    sudo apt-get install nginx -y
    if [ $? -ne 0 ]; then
        echo "nginx安装失败，请检查您的系统是否安装apt。(请执行sudo apt update && sudo apt upgrade -y)" >&2
        exit 1
    fi
fi

# nginx配置文件下载地址
url="https://raw.githubusercontent.com/aquasofts/emby/main/emby"

# 目标目录
destination="/etc/nginx/sites-available/"

# 使用wget命令下载文件到目标目录
if command -v wget >/dev/null 2>&1; then
    sudo wget -P "$destination" "$url"
    if [ $? -ne 0 ]; then
        echo "文件下载失败，请检查网络连接。" >&2
        exit 1
    fi
else
    echo "wget命令未找到，请安装wget。" >&2
    exit 1
fi

# 提示用户操作完成
echo "文件已拉取完成"

# 提示用户输入自己的域名
echo "请输入您的域名(需要解析到这台机器上)："
read -r domain

# 替换/etc/nginx/sites-available/emby中的yourdomain为用户输入的域名
sudo sed -i "s|yourdomain|$domain|g" /etc/nginx/sites-available/emby
if [ $? -ne 0 ]; then
    echo "域名替换失败，请检查文件路径和权限。" >&2
    exit 1
fi

# 提示用户emby域名
echo "请输入您需要反代的域名："
read -r content2

# 替换/etc/nginx/sites-available/emby中的embydomain为用户输入的emby域名
sudo sed -i "s|embydomain|$content2|g" /etc/nginx/sites-available/emby
if [ $? -ne 0 ]; then
    echo "反代的域名替换失败，请检查文件路径和权限。" >&2
    exit 1
fi

# 链接配置
if [ -f /etc/nginx/sites-available/emby ]; then
    sudo ln -sf /etc/nginx/sites-available/emby /etc/nginx/sites-enabled/
    if [ $? -ne 0 ]; then
        echo "配置链接失败，请检查文件路径和权限。" >&2
        exit 1
    fi
else
    echo "/etc/nginx/sites-available/emby 文件不存在。" >&2
    exit 1
fi

# 重启nginx
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl restart nginx
    if [ $? -ne 0 ]; then
        echo "nginx重启失败，请检查nginx配置。" >&2
        exit 1
    fi
else
    echo "systemctl命令未找到，请手动重启nginx。" >&2
    exit 1
fi

echo "脚本执行完成 您的链接为 http://$domain"