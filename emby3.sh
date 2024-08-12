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

#安装acme.sh
install_acme(){
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
    echo "wget命令未找到，请安装wget。" >&2
    exit 1
fi

# 提示用户操作完成
echo "文件已拉取完成"

getSingleCert(){
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && red "未安装acme.sh，无法执行操作" && exit 1
    check_80
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    ipv4=$(curl -s4m8 https://ip.gs)
    ipv6=$(curl -s6m8 https://ip.gs)
    realip=$(curl -sm8 http://ip.sb)
    # 提示用户输入自己的域名
    read -rp "请输入解析完成的域名:" domain
    [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
    green "已输入的域名：$domain" && sleep 1
    domainIP=$(curl -sm8 ipget.net/?ip=misaka.sama."$domain")
    if [[ -n $(echo $domainIP | grep nginx) ]]; then
        domainIP=$(curl -sm8 ipget.net/?ip="$domain")
        if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
            if [[ -n $(echo $realip | grep ":") ]]; then
                bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6
            else
                bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256
            fi
        else
            if [[ $domainIP == $ipv6 ]]; then
                bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6
            fi
            if [[ $domainIP == $ipv4 ]]; then
                bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256
            fi
        fi

        if [[ -n $(echo $domainIP | grep nginx) ]]; then
            yellow "域名解析无效，请检查域名是否填写正确或稍等几分钟等待解析完成再执行脚本"
            exit 1
        elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
            if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]] && [[ $domainIP != $realip ]]; then
                green "${domain} 解析结果：（$domainIP）"
                red "当前域名解析的IP与当前VPS使用的真实IP不匹配"
                green "建议如下："
                yellow "1. 请确保CloudFlare小云朵为关闭状态(仅限DNS)，其他域名解析网站设置同理"
                yellow "2. 请检查DNS解析设置的IP是否为VPS的真实IP"
                yellow "3. 脚本可能跟不上时代，建议截图发布到GitHub Issues或TG群询问"
                exit 1
            fi
        fi
    else
        red "疑似泛域名解析，请使用泛域名申请模式"
        back2menu
    fi
    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /root/private.key --fullchain-file /root/cert.crt --ecc
    checktls
}

# 替换/etc/nginx/sites-available/emby3中的yourdomain为用户输入的域名
sudo sed -i "s|yourdomain|$domain|g" /etc/nginx/sites-available/emby3
if [ $? -ne 0 ]; then
    echo "域名替换失败，请检查文件路径和权限。" >&2
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

echo "脚本执行完成 您的链接为 https://$domain"
