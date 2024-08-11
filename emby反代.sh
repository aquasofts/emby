#!/bin/bash
#更新apt
sudo apt update && sudo apt upgrade -y

#安装nginx
sudo apt-get install nginx -y

# nginx配置文件下载地址
url="https://raw.githubusercontent.com/aquasofts/emby/main/emby"

# 目标目录
destination="/etc/nginx/sites-available/"

# 使用wget命令下载文件到目标目录
sudo wget -P $destination $url

# 提示用户操作完成
echo "文件已拉取完成"

# 提示用户输入内容1
echo "请输入您的域名："
read content1

# 替换/etc/nginx/sites-available/emby中的yourdomain为用户输入的域名
sudo sed -i "s/yourdomain/$content1/g" /etc/nginx/sites-available/emby

# 提示用户输入内容2
echo "请输入第二个内容："
read content2

# 替换/etc/nginx/sites-available/emby中的embydomain为用户输入的emby域名
sudo sed -i "s/embydomain/$content2/g" /etc/nginx/sites-available/emby


#链接配置
sudo ln -s /etc/nginx/sites-available/emby /etc/nginx/sites-enabled/

#重启nginx
systemctl restart nginx
