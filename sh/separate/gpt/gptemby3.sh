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

# OS 识别和包管理器设置
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法检测操作系统类型，脚本不支持该系统。"
    exit 1
fi

# 环境清理
clean(){
    apt --fix-broken install
}

# 检查并安装 Nginx
install_nginx(){
    if command -v nginx >/dev/null 2>&1; then
        green "nginx已安装"
    else
        sudo apt-get install nginx -y || { red "nginx安装失败，请检查您的系统是否安装apt。"; exit 1; }
    fi
}

# 安装 Cron
install_cron() {
    case "$OS" in
        ubuntu|debian)
            echo "正在为 $OS 安装 cron..."
            sudo apt-get update && sudo apt-get install -y cron
            sudo systemctl enable cron && sudo systemctl start cron
            ;;
        centos|rhel|fedora|rocky|alma|oracle)
            echo "正在为 $OS 安装 cronie..."
            sudo yum install -y cronie
            sudo systemctl enable crond && sudo systemctl start crond
            ;;
        amazon)
            echo "正在为 $OS 安装 cronie..."
            sudo yum install -y cronie
            sudo systemctl enable crond && sudo systemctl start crond
            ;;
        *)
            echo "不支持的操作系统：$OS"
            exit 1
            ;;
    esac
}

# 安装 acme.sh 和 socat
install_acme(){
    if [[ "$OS" == "centos" ]]; then
        yum install socat -y
    else
        apt install socat -y
    fi

    [[ $? -ne 0 ]] && { LOGE "无法安装socat,请检查错误日志"; exit 1; }

    certPath="/root/cert"
    mkdir -p "$certPath"

    curl https://get.acme.sh | sh
    source ~/.bashrc
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

    LOGI "Acme.sh证书申请脚本安装成功！"
}

# 获取和安装证书
get_cert(){
    sudo service nginx stop
    read -p "请输入你的域名: " domain
    LOGD "你输入的域名为: ${domain}, 正在进行域名合法性校验..."

    if [[ $(~/.acme.sh/acme.sh --list | grep -c "$domain") -gt 0 ]]; then
        green "已有证书，请删除相关目录后重新申请"
        return
    fi

    read -p "请输入你所希望使用的端口 (推荐使用80端口): " WebPort
    [[ $WebPort -lt 1 || $WebPort -gt 65535 ]] && WebPort=80

    LOGI "将使用${WebPort}进行证书申请，请确保端口开放..."
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone --httpport "$WebPort"
    [[ $? -ne 0 ]] && { red "证书申请失败"; exit 1; }

    LOGI "证书申请成功，开始安装..."
    ~/.acme.sh/acme.sh --installcert -d "$domain" --ca-file "$certPath/ca.cer" \
        --cert-file "$certPath/${domain}.cer" --key-file "$certPath/${domain}.key" \
        --fullchain-file "$certPath/fullchain.cer"

    [[ $? -ne 0 ]] && { LOGE "证书安装失败"; exit 1; }
    LOGI "证书安装成功，已开启自动更新..."
}

# 替换配置文件中的占位符
replace_config(){
    sudo sed -i "s|yourdomain|$1|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|embydomain|$2|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|jjkk|$1|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|hhjj|$1|g" /etc/nginx/sites-available/emby3sep
}

# 第二个域名证书处理
get_stream_cert(){
    sudo service nginx stop
    read -p "请输入你的第二个域名: " aall
    LOGD "你输入的域名为: ${aall}, 正在进行域名合法性校验..."

    if [[ $(~/.acme.sh/acme.sh --list | grep -c "$aall") -gt 0 ]]; then
        green "已有证书，请删除相关目录后重新申请"
        return
    fi

    read -p "请输入你希望使用的端口 (推荐80端口): " WebPort
    [[ $WebPort -lt 1 || $WebPort -gt 65535 ]] && WebPort=80

    LOGI "将使用${WebPort}申请证书，请确保端口开放..."
    ~/.acme.sh/acme.sh --issue -d "$aall" --standalone --httpport "$WebPort"
    [[ $? -ne 0 ]] && { red "证书申请失败"; exit 1; }

    LOGI "证书申请成功，开始安装..."
    ~/.acme.sh/acme.sh --installcert -d "$aall" --ca-file "$certPath/ca.cer" \
        --cert-file "$certPath/${aall}.cer" --key-file "$certPath/${aall}.key" \
        --fullchain-file "$certPath/fullchain.cer"

    [[ $? -ne 0 ]] && { LOGE "证书安装失败"; exit 1; }
    LOGI "证书安装成功，开启自动更新..."
}

replace_stream_config(){
    sudo sed -i "s|weasd|$1|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|ggdd|$2|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|qqww|$1|g" /etc/nginx/sites-available/emby3sep
    sudo sed -i "s|eeww|$1|g" /etc/nginx/sites-available/emby3sep
}

# 配置链接
link_nginx_config(){
    sudo ln -sf /etc/nginx/sites-available/emby3sep /etc/nginx/sites-enabled/
    sudo systemctl restart nginx || { red "nginx重启失败，请检查配置。"; exit 1; }
}

# 执行结果展示
result(){
    green "脚本执行完成，您的链接为 https://$domain"
}

# 主流程控制
main(){
    clean
    install_nginx
    install_cron
    install_acme
    download_file
    
    get_cert
    read -p "请输入反代的域名: " emby_domain
    replace_config "$domain" "$emby_domain"

    get_stream_cert
    read -p "请输入反代的推流域名: " stream_domain
    replace_stream_config "$aall" "$stream_domain"

    link_nginx_config
    result
}

main