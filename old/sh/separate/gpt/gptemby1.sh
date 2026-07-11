#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# 优化的颜色打印函数
red(){ echo -e "${RED}\033[01m$1${PLAIN}"; }
green(){ echo -e "${GREEN}\033[01m$1${PLAIN}"; }
yellow(){ echo -e "${YELLOW}\033[01m$1${PLAIN}"; }

# 优化的日志函数
LOGD(){ yellow "[DEG] $*"; }
LOGE(){ red "[ERR] $*"; }
LOGI(){ green "[INF] $*"; }

# 清理环境
clean(){
    apt --fix-broken install
}

# 检查并安装Nginx
install_nginx(){
    if command -v nginx >/dev/null 2>&1; then
        LOGI "nginx已安装"
    else
        sudo apt-get install nginx -y || { LOGE "nginx安装失败，请检查您的系统是否安装apt。"; exit 1; }
    fi
}

# 下载Nginx配置文件
download_file(){
    local url="https://raw.githubusercontent.com/aquasofts/emby/main/file/separate/emby1sep"
    local destination="/etc/nginx/sites-available/emby1sep"

    if command -v wget >/dev/null 2>&1; then
        sudo wget -O "$destination" "$url" || { LOGD "全新安装，无需覆盖"; sudo wget -P "$(dirname "$destination")" "$url"; }
        LOGI "文件已成功下载到 $destination"
    else
        LOGE "wget未找到，请安装wget。"
        exit 1
    fi
}

# 替换占位符函数
replace_placeholder(){
    local file="$1"
    local placeholder="$2"
    local replacement="$3"
    sudo sed -i "s|$placeholder|$replacement|g" "$file" || { LOGE "替换$placeholder失败，请检查文件路径和权限。"; exit 1; }
}

# 提示并替换用户输入的信息
replace_info(){
    local prompt_msg="$1"
    local file="$2"
    local placeholder="$3"

    read -p "$prompt_msg" input
    replace_placeholder "$file" "$placeholder" "$input"
}

# 链接Nginx配置
link_nginx_config(){
    local file="/etc/nginx/sites-available/emby1sep"
    if [ -f "$file" ]; then
        sudo ln -sf "$file" /etc/nginx/sites-enabled/ || { LOGE "配置链接失败"; exit 1; }
        sudo systemctl restart nginx || { LOGE "nginx重启失败"; exit 1; }
    else
        LOGE "$file 文件不存在。"
        exit 1
    fi
}

# 主流程控制
main(){
    clean
    install_nginx
    download_file

    replace_info "请输入您的域名(需要解析到这台机器上)：" "/etc/nginx/sites-available/emby1sep" "yourdomain"
    replace_info "请输入您要反代推流服务器的域名：" "/etc/nginx/sites-available/emby1sep" "weasd"
    replace_info "请输入您需要反代的域名(仅填写域名，例如'baidu.com')：" "/etc/nginx/sites-available/emby1sep" "embydomain"
    replace_info "请输入您需要反代的推流域名(仅填写域名，例如'baidu.com')：" "/etc/nginx/sites-available/emby1sep" "ggdd"

    link_nginx_config

    LOGI "脚本执行完成，您的链接为 http://$input"
}

main
