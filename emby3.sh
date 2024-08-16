#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
ho -e "\033[32m\033[01m$1\033[0m"
}
function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}


REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get -y update" "apt-get -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法检测操作系统类型，脚本不支持该系统。"
    exit 1
fi

#清除环境
clean(){
apt --fix-broken install
}

# 检查并安装nginx
install_nginx(){
if command -v nginx >/dev/null 2>&1; then
    green "nginx已安装"
else
    sudo apt-get install nginx -y
    if [ $? -ne 0 ]; then
        red "nginx安装失败，请检查您的系统是否安装apt。" >&2
        red "可执行 sudo apt update && sudo apt upgrade -y 来安装相关环境"
        exit 1
    fi
fi
}

#安装corn
install_cron() {
    case "$OS" in
        ubuntu|debian)
            echo "正在为 $OS 安装 cron..."
            sudo apt-get update && sudo apt-get install -y cron
            sudo systemctl enable cron
            sudo systemctl start cron
            ;;
        centos|rhel|fedora|rocky|alma|oracle)
            echo "正在为 $OS 安装 cronie..."
            sudo yum install -y cronie
            sudo systemctl enable crond
            sudo systemctl start crond
            ;;
        amazon)
            echo "正在为 $OS 安装 cron..."
            sudo yum install -y cronie
            sudo systemctl enable crond
            sudo systemctl start crond
            ;;
        arch|manjaro)
            echo "正在为 $OS 安装 cronie..."
            sudo pacman -Sy --noconfirm cronie
            sudo systemctl enable cronie
            sudo systemctl start cronie
            ;;
        *)
            echo "不支持的操作系统：$OS"
            exit 1
            ;;
    esac
}

#安装acme.sh
install_acme(){
    #install socat second
    if [[ x"${release}" == x"centos" ]]; then
        yum install socat -y
    else
        apt install socat -y
    fi
    if [ $? -ne 0 ]; then
        LOGE "无法安装socat,请检查错误日志"
        exit 1
    else
        LOGI "socat安装成功..."
    fi
    #creat a directory for install cert
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    fi
   #安装crontab
   sudo apt-get install cron
   sudo systemctl enable cron
   sudo systemctl start cron
    [[ ! $SYSTEM == "CentOS" ]] && ${PACKAGE_UPDATE[int]}
    [[ -z $(type -P curl) ]] && ${PACKAGE_INSTALL[int]} curl
    [[ -z $(type -P wget) ]] && ${PACKAGE_INSTALL[int]} wget
    [[ -z $(type -P socat) ]] && ${PACKAGE_INSTALL[int]} socat
    [[ -z $(type -P cron) && $SYSTEM =~ Debian|Ubuntu ]] && ${PACKAGE_INSTALL[int]} cron && systemctl start cron && systemctl enable cron
    [[ -z $(type -P crond) && $SYSTEM == CentOS ]] && ${PACKAGE_INSTALL[int]} cronie && systemctl start crond && systemctl enable crond
    read -rp "请输入注册邮箱（例：admin@gmail.com，或留空自动生成）：" acmeEmail
    [[ -z $acmeEmail ]] && autoEmail=$(date +%s%N | md5sum | cut -c 1-32) && acmeEmail=$autoEmail@gmail.com
    curl https://get.acme.sh | sh -s email=$acmeEmail
    source ~/.bashrc
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        green "Acme.sh证书申请脚本安装成功！"
    else
        red "抱歉，Acme.sh证书申请脚本安装失败"
        green "建议如下："
        yellow "1. 检查VPS的网络环境"
        yellow "2. 脚本可能跟不上时代，建议截图发布到GitHub Issues或TG群询问"
    fi
    back2menu
}

download_file(){
# nginx配置文件下载地址
url="https://raw.githubusercontent.com/aquasofts/emby/main/emby3"

# 目标文件路径（包括文件名）
destination="/etc/nginx/sites-available/emby3"

# 使用wget命令下载文件到目标文件路径
if command -v wget >/dev/null 2>&1; then
    sudo wget -O "$destination" "$url"
    if [ $? -ne 0 ]; then
        echo "全新安装，无需覆盖" >&2
        
        # 下载文件
        sudo wget -P "$(dirname "$destination")" "$url"
        if [ $? -ne 0 ]; then
            echo "下载失败，请检查网络连接。" >&2
            exit 1
        else
            echo "文件已成功下载到 $(dirname "$destination")"
        fi
    else
        echo "文件已成功下载并覆盖到 $destination"
    fi
else
    red "wget命令未找到，请安装wget。" >&2
    exit 1
fi

# 提示用户操作完成
echo "文件已拉取完成"
}

get_cert(){
    #stop nginx
    sudo service nginx stop
    #get the domain here,and we need verify it
    export domain=""
    read -p "请输入你的域名:" domain
    LOGD "你输入的域名为:${domain},正在进行域名合法性校验..."
    #here we need to judge whether there exists cert already
    local currentCert=$(~/.acme.sh/acme.sh --list | grep ${domain} | wc -l)
    if [ ${currentCert} -ne 0 ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
    # 使用 rm -rf 删除 /root/${domain}_ecc 目录
    green "已有证书，请使用脚本2，或删除相关目录重新申请，为避免滥用本处不提供教程"
    else
        green "域名合法性校验通过..."
    fi

    #get needed port here
    local WebPort=80
    read -p "请输入你所希望使用的端口(推荐使用80端口):" WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        green "你所选择的端口${WebPort}为无效值,将使用默认80端口进行申请"
    fi
    LOGI "将会使用${WebPort}进行证书申请,请确保端口处于开放状态..."
    #NOTE:This should be handled by user
    #open the port and kill the occupied progress
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        red "证书申请失败,原因请参见报错信息"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        green "证书申请成功,开始安装证书..."
    fi
    #install cert
    ~/.acme.sh/acme.sh --installcert -d ${domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer --key-file /root/cert/${domain}.key \
        --fullchain-file /root/cert/fullchain.cer

    if [ $? -ne 0 ]; then
        LOGE "证书安装失败,脚本退出"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        LOGI "证书安装成功,开启自动更新..."
    fi
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        LOGE "自动更新设置失败,脚本退出"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        LOGI "证书已安装且已开启自动更新,具体信息如下"
        ls -lah cert
        chmod 755 $certPath
    fi
}

Replace(){
# 替换/etc/nginx/sites-available/emby3中的yourdomain为用户输入的域名
sudo sed -i "s|yourdomain|$domain|g" /etc/nginx/sites-available/emby3
if [ $? -ne 0 ]; then
    red "域名替换失败，请检查文件路径和权限。" >&2
    exit 1
fi

# 提示用户emby域名
echo "请输入您需要反代的域名：(仅填写域名，例如"baidu.com")"
read -r content2

# 替换/etc/nginx/sites-available/emby3中的embydomain为用户输入的emby域名
sudo sed -i "s|embydomain|$content2|g" /etc/nginx/sites-available/emby3
if [ $? -ne 0 ]; then
    echo "反代的域名替换失败，请检查文件路径和权限。" >&2
    exit 1
fi

# 替换/etc/nginx/sites-available/emby3中的jjkk为证书公钥目录
sudo sed -i "s|jjkk|$domain|g" /etc/nginx/sites-available/emby3
if [ $? -ne 0 ]; then
    echo "证书公钥替换失败，请检查文件路径和权限。" >&2
    exit 1
fi

# 替换/etc/nginx/sites-available/emby3中的hhjj为证书公钥目录
sudo sed -i "s|hhjj|$domain|g" /etc/nginx/sites-available/emby3
if [ $? -ne 0 ]; then
    echo "证书私钥替换失败，请检查文件路径和权限。" >&2
    exit 1
fi
}

Link(){
# 链接配置
if [ -f /etc/nginx/sites-available/emby3 ]; then
    sudo ln -sf /etc/nginx/sites-available/emby3 /etc/nginx/sites-enabled/
    if [ $? -ne 0 ]; then
        echo "配置链接失败，请检查文件路径和权限。" >&2
        exit 1
    fi
else
    echo "/etc/nginx/sites-available/emby3 文件不存在。" >&2
    exit 1
fi
}

restart_nginx(){
# 重启nginx
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl restart nginx
    if [ $? -ne 0 ]; then
        red "nginx重启失败，请检查nginx配置。" >&2
        exit 1
    fi
else
    echo "systemctl命令未找到，请手动重启nginx。" >&2
    exit 1
fi
}

result(){
green "脚本执行完成 您的链接为 https://$domain"
}

main(){
clean
install_nginx
install_cron
install_acme
download_file
get_cert
Replace
Link
restart_nginx
result
}

main