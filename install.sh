#!/usr/bin/env bash

set -Eeuo pipefail

readonly VERSION="2.0.0"
readonly CONFIG_NAME="emby-proxy"
readonly CONFIG_FILE="/etc/nginx/sites-available/${CONFIG_NAME}"
readonly ENABLED_FILE="/etc/nginx/sites-enabled/${CONFIG_NAME}"

ACTION="install"
PUBLIC_DOMAIN=""
UPSTREAM=""
STREAM_DOMAIN=""
STREAM_UPSTREAM=""
TLS_MODE="auto"
CERT_FILE=""
KEY_FILE=""
STREAM_CERT_FILE=""
STREAM_KEY_FILE=""
EMAIL=""
NON_INTERACTIVE=0
DRY_RUN=0
TEMP_CONFIG=""

if [[ -t 1 ]]; then
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RESET=$'\033[0m'
else
    RED=""
    GREEN=""
    YELLOW=""
    RESET=""
fi

info() { printf '%s[信息]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s[提示]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s[错误]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

cleanup() {
    [[ -z $TEMP_CONFIG ]] || rm -f "$TEMP_CONFIG"
}
trap cleanup EXIT

usage() {
    cat <<'EOF'
Emby Nginx 反向代理安装器

用法：
  ./install.sh                         交互式安装
  ./install.sh [选项] --yes           非交互式安装
  ./install.sh --uninstall            安全移除本脚本创建的配置

选项：
  --domain DOMAIN                     对外访问域名
  --upstream URL                      Emby 源站，例如 http://127.0.0.1:8096
  --tls auto|manual|off               自动证书、已有证书或仅 HTTP（默认 auto）
  --cert PATH                         manual 模式的证书链
  --key PATH                          manual 模式的私钥
  --email EMAIL                       Certbot 通知邮箱（auto 模式可选）
  --stream-domain DOMAIN              可选的独立推流域名
  --stream-upstream URL               推流源站；省略时使用 --upstream
  --stream-cert PATH                  推流域名证书；省略时使用 --cert
  --stream-key PATH                   推流域名私钥；省略时使用 --key
  --yes                               跳过交互和最终确认
  --dry-run                           只输出 Nginx 配置，不修改系统
  --uninstall                         移除 emby-proxy 配置
  -h, --help                          显示帮助
  -v, --version                       显示版本

示例：
  ./install.sh --domain media.example.com \
    --upstream http://127.0.0.1:8096 --tls auto --email me@example.com --yes
EOF
}

need_value() {
    [[ $# -ge 2 && -n ${2:-} ]] || die "$1 需要一个值"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)          need_value "$@"; PUBLIC_DOMAIN=$2; shift 2 ;;
            --upstream)        need_value "$@"; UPSTREAM=$2; shift 2 ;;
            --stream-domain)   need_value "$@"; STREAM_DOMAIN=$2; shift 2 ;;
            --stream-upstream) need_value "$@"; STREAM_UPSTREAM=$2; shift 2 ;;
            --tls)             need_value "$@"; TLS_MODE=$2; shift 2 ;;
            --cert)            need_value "$@"; CERT_FILE=$2; shift 2 ;;
            --key)             need_value "$@"; KEY_FILE=$2; shift 2 ;;
            --stream-cert)     need_value "$@"; STREAM_CERT_FILE=$2; shift 2 ;;
            --stream-key)      need_value "$@"; STREAM_KEY_FILE=$2; shift 2 ;;
            --email)           need_value "$@"; EMAIL=$2; shift 2 ;;
            --yes)             NON_INTERACTIVE=1; shift ;;
            --dry-run)         DRY_RUN=1; NON_INTERACTIVE=1; shift ;;
            --uninstall)       ACTION="uninstall"; shift ;;
            -h|--help)         usage; exit 0 ;;
            -v|--version)      printf '%s\n' "$VERSION"; exit 0 ;;
            *)                 die "未知选项：$1（使用 --help 查看帮助）" ;;
        esac
    done
}

prompt_required() {
    local prompt=$1
    local value=""
    while [[ -z $value ]]; do
        read -r -p "$prompt" value
    done
    printf '%s' "$value"
}

interactive_setup() {
    cat <<'EOF'

Emby 反向代理快速配置
只需要提供访问域名和 Emby 源站，其余工作会自动完成。

EOF
    PUBLIC_DOMAIN=$(prompt_required "访问域名（如 media.example.com）：")
    read -r -p "Emby 源站 [http://127.0.0.1:8096]：" UPSTREAM
    UPSTREAM=${UPSTREAM:-http://127.0.0.1:8096}

    printf '\nHTTPS 方式：\n  1) 自动申请并续期证书（推荐）\n  2) 使用已有证书\n  3) 仅 HTTP\n'
    local tls_choice=""
    read -r -p "请选择 [1]：" tls_choice
    case "${tls_choice:-1}" in
        1) TLS_MODE="auto" ;;
        2) TLS_MODE="manual" ;;
        3) TLS_MODE="off" ;;
        *) die "无效的 HTTPS 选项" ;;
    esac

    if [[ $TLS_MODE == "manual" ]]; then
        CERT_FILE=$(prompt_required "证书链绝对路径：")
        KEY_FILE=$(prompt_required "私钥绝对路径：")
    elif [[ $TLS_MODE == "auto" ]]; then
        read -r -p "证书通知邮箱（可留空）：" EMAIL
    fi

    local use_stream=""
    read -r -p "是否使用独立推流域名？[y/N]：" use_stream
    if [[ $use_stream =~ ^[Yy]$ ]]; then
        STREAM_DOMAIN=$(prompt_required "推流访问域名：")
        read -r -p "推流源站 [${UPSTREAM}]：" STREAM_UPSTREAM
        STREAM_UPSTREAM=${STREAM_UPSTREAM:-$UPSTREAM}
        if [[ $TLS_MODE == "manual" ]]; then
            read -r -p "推流证书链 [与主域名相同]：" STREAM_CERT_FILE
            read -r -p "推流私钥 [与主域名相同]：" STREAM_KEY_FILE
        fi
    fi
}

valid_domain() {
    local domain=$1
    [[ ${#domain} -le 253 ]] || return 1
    [[ $domain == *.* && $domain != *..* ]] || return 1
    local labels=()
    local label
    IFS='.' read -r -a labels <<<"$domain"
    [[ ${#labels[@]} -ge 2 ]] || return 1
    for label in "${labels[@]}"; do
        [[ ${#label} -le 63 ]] || return 1
        [[ $label =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
    done
}

valid_upstream() {
    [[ $1 =~ ^https?://([A-Za-z0-9._-]+|\[[0-9A-Fa-f:]+\])(:[0-9]{1,5})?/?$ ]] || return 1
    local port=${BASH_REMATCH[2]#:}
    [[ -z $port || (10#$port -ge 1 && 10#$port -le 65535) ]]
}

valid_certificate_path() {
    [[ $1 == /* ]] || return 1
    [[ $1 != *$'\n'* && $1 != *$'\r'* && $1 != *'"'* && $1 != *'$'* && $1 != *'\'* ]]
}

validate_email() {
    [[ -z $1 || $1 =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

validate_inputs() {
    [[ -n $PUBLIC_DOMAIN ]] || die "缺少 --domain"
    [[ -n $UPSTREAM ]] || die "缺少 --upstream"
    valid_domain "$PUBLIC_DOMAIN" || die "访问域名格式无效：$PUBLIC_DOMAIN"
    valid_upstream "$UPSTREAM" || die "源站必须是无路径的 http(s) URL，例如 http://127.0.0.1:8096"
    UPSTREAM=${UPSTREAM%/}

    case "$TLS_MODE" in
        auto|manual|off) ;;
        *) die "--tls 只支持 auto、manual 或 off" ;;
    esac
    validate_email "$EMAIL" || die "邮箱格式无效：$EMAIL"

    if [[ -n $STREAM_DOMAIN ]]; then
        valid_domain "$STREAM_DOMAIN" || die "推流域名格式无效：$STREAM_DOMAIN"
        [[ $STREAM_DOMAIN != "$PUBLIC_DOMAIN" ]] || die "主域名和推流域名不能相同"
        STREAM_UPSTREAM=${STREAM_UPSTREAM:-$UPSTREAM}
        valid_upstream "$STREAM_UPSTREAM" || die "推流源站必须是无路径的 http(s) URL"
        STREAM_UPSTREAM=${STREAM_UPSTREAM%/}
    elif [[ -n $STREAM_UPSTREAM ]]; then
        die "使用 --stream-upstream 时必须同时提供 --stream-domain"
    fi

    if [[ $TLS_MODE == "manual" ]]; then
        valid_certificate_path "$CERT_FILE" && valid_certificate_path "$KEY_FILE" || \
            die "manual 模式需要安全的 --cert 和 --key 绝对路径"
        STREAM_CERT_FILE=${STREAM_CERT_FILE:-$CERT_FILE}
        STREAM_KEY_FILE=${STREAM_KEY_FILE:-$KEY_FILE}
        valid_certificate_path "$STREAM_CERT_FILE" && valid_certificate_path "$STREAM_KEY_FILE" || \
            die "推流证书和私钥必须是安全的绝对路径"
    fi
}

confirm_install() {
    [[ $NON_INTERACTIVE -eq 1 ]] && return
    printf '\n即将配置：\n  访问地址：%s://%s\n  Emby 源站：%s\n' \
        "$([[ $TLS_MODE == off ]] && printf http || printf https)" "$PUBLIC_DOMAIN" "$UPSTREAM"
    if [[ -n $STREAM_DOMAIN ]]; then
        printf '  推流地址：%s://%s\n  推流源站：%s\n' \
            "$([[ $TLS_MODE == off ]] && printf http || printf https)" "$STREAM_DOMAIN" "$STREAM_UPSTREAM"
    fi
    local answer=""
    read -r -p "继续？[Y/n]：" answer
    [[ ! $answer =~ ^[Nn]$ ]] || die "已取消"
}

proxy_location() {
    local upstream=$1
    local rewrite_stream=${2:-0}
    cat <<EOF
    location / {
        proxy_pass ${upstream};
        proxy_http_version 1.1;
        proxy_set_header Host \$proxy_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$emby_connection_upgrade;
        proxy_ssl_server_name on;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
EOF
    if [[ $rewrite_stream -eq 1 ]]; then
        local stream_authority=${STREAM_UPSTREAM#*://}
        local public_scheme="https"
        [[ $TLS_MODE == "off" ]] && public_scheme="http"
        cat <<EOF

        # 前后端分离模式：只对文本响应改写推流地址。
        proxy_set_header Accept-Encoding "";
        sub_filter_once off;
        sub_filter_types text/css text/javascript application/javascript application/json application/xml;
        sub_filter "http://${stream_authority}" "${public_scheme}://${STREAM_DOMAIN}";
        sub_filter "https://${stream_authority}" "${public_scheme}://${STREAM_DOMAIN}";
        sub_filter "\"${stream_authority}\"" "\"${STREAM_DOMAIN}\"";
EOF
    fi
    cat <<'EOF'
    }
EOF
}

http_server() {
    local domain=$1
    local upstream=$2
    local rewrite_stream=${3:-0}
    cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    client_max_body_size 0;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
EOF
    proxy_location "$upstream" "$rewrite_stream"
    cat <<'EOF'
}

EOF
}

redirect_server() {
    local domain=$1
    cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    return 301 https://\$host\$request_uri;
}

EOF
}

https_server() {
    local domain=$1
    local upstream=$2
    local cert=$3
    local key=$4
    local rewrite_stream=${5:-0}
    cat <<EOF
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${domain};

    ssl_certificate "${cert}";
    ssl_certificate_key "${key}";
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_protocols TLSv1.2 TLSv1.3;

    client_max_body_size 0;
    add_header Strict-Transport-Security "max-age=15552000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
EOF
    proxy_location "$upstream" "$rewrite_stream"
    cat <<'EOF'
}

EOF
}

generate_config() {
    cat <<EOF
# Generated by emby-proxy installer ${VERSION}.
# Re-run install.sh to update this file safely.

map \$http_upgrade \$emby_connection_upgrade {
    default upgrade;
    ''      close;
}

EOF
    local rewrite_main=0
    [[ -n $STREAM_DOMAIN ]] && rewrite_main=1

    case "$TLS_MODE" in
        off|auto)
            # Certbot needs a working HTTP virtual host before it can add TLS.
            http_server "$PUBLIC_DOMAIN" "$UPSTREAM" "$rewrite_main"
            if [[ -n $STREAM_DOMAIN ]]; then
                http_server "$STREAM_DOMAIN" "$STREAM_UPSTREAM" 0
            fi
            ;;
        manual)
            redirect_server "$PUBLIC_DOMAIN"
            https_server "$PUBLIC_DOMAIN" "$UPSTREAM" "$CERT_FILE" "$KEY_FILE" "$rewrite_main"
            if [[ -n $STREAM_DOMAIN ]]; then
                redirect_server "$STREAM_DOMAIN"
                https_server "$STREAM_DOMAIN" "$STREAM_UPSTREAM" "$STREAM_CERT_FILE" "$STREAM_KEY_FILE" 0
            fi
            ;;
    esac
}

SUDO=()
init_privileges() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        command -v sudo >/dev/null 2>&1 || die "请使用 root 运行，或先安装 sudo"
        SUDO=(sudo)
        "${SUDO[@]}" -v
    fi
}

run_root() {
    "${SUDO[@]}" "$@"
}

install_dependencies() {
    local packages=()
    if ! command -v nginx >/dev/null 2>&1 && [[ ! -x /usr/sbin/nginx ]]; then
        packages+=(nginx)
    fi
    if [[ $TLS_MODE == "auto" ]]; then
        command -v certbot >/dev/null 2>&1 || packages+=(certbot)
        if ! command -v dpkg-query >/dev/null 2>&1 || ! dpkg-query -W -f='${Status}' python3-certbot-nginx 2>/dev/null | grep -q 'ok installed'; then
            packages+=(python3-certbot-nginx)
        fi
    fi
    [[ ${#packages[@]} -gt 0 ]] || return

    command -v apt-get >/dev/null 2>&1 || die "当前版本仅自动支持 Debian/Ubuntu；请手动安装：${packages[*]}"
    info "安装缺少的组件：${packages[*]}"
    run_root apt-get update
    run_root apt-get install -y "${packages[@]}"
}

nginx_binary() {
    if command -v nginx >/dev/null 2>&1; then
        command -v nginx
    elif [[ -x /usr/sbin/nginx ]]; then
        printf '%s' /usr/sbin/nginx
    else
        die "找不到 nginx"
    fi
}

reload_nginx() {
    if command -v systemctl >/dev/null 2>&1; then
        run_root systemctl enable nginx >/dev/null
        if run_root systemctl is-active --quiet nginx; then
            run_root systemctl reload nginx
        else
            run_root systemctl start nginx
        fi
    else
        local nginx_bin
        nginx_bin=$(nginx_binary)
        if pgrep -x nginx >/dev/null 2>&1; then
            run_root "$nginx_bin" -s reload
        else
            run_root "$nginx_bin"
        fi
    fi
}

check_manual_certificates() {
    [[ $TLS_MODE == "manual" ]] || return
    run_root test -f "$CERT_FILE" || die "证书不存在：$CERT_FILE"
    run_root test -f "$KEY_FILE" || die "私钥不存在：$KEY_FILE"
    if [[ -n $STREAM_DOMAIN ]]; then
        run_root test -f "$STREAM_CERT_FILE" || die "推流证书不存在：$STREAM_CERT_FILE"
        run_root test -f "$STREAM_KEY_FILE" || die "推流私钥不存在：$STREAM_KEY_FILE"
    fi
}

deploy_config() {
    local generated=$1
    local nginx_bin
    nginx_bin=$(nginx_binary)
    local had_config=0
    local had_link=0

    run_root mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    if run_root test -e "$CONFIG_FILE"; then
        had_config=1
        run_root cp -a "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    fi
    run_root test -L "$ENABLED_FILE" && had_link=1

    run_root install -m 0644 "$generated" "$CONFIG_FILE"
    run_root ln -sfn "$CONFIG_FILE" "$ENABLED_FILE"

    if ! run_root "$nginx_bin" -t; then
        warn "新配置检查失败，正在恢复原配置"
        if [[ $had_config -eq 1 ]]; then
            run_root cp -a "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        else
            run_root rm -f "$CONFIG_FILE"
        fi
        [[ $had_link -eq 1 ]] || run_root rm -f "$ENABLED_FILE"
        die "Nginx 配置无效，系统已回滚"
    fi

    if ! reload_nginx; then
        warn "Nginx 重载失败，正在恢复原配置"
        if [[ $had_config -eq 1 ]]; then
            run_root cp -a "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        else
            run_root rm -f "$CONFIG_FILE"
        fi
        [[ $had_link -eq 1 ]] || run_root rm -f "$ENABLED_FILE"
        run_root "$nginx_bin" -t >/dev/null 2>&1 && reload_nginx >/dev/null 2>&1 || true
        die "部署失败，系统已回滚"
    fi
}

request_certificate() {
    local args=(certbot --nginx --redirect --non-interactive --agree-tos --keep-until-expiring -d "$PUBLIC_DOMAIN")
    [[ -n $STREAM_DOMAIN ]] && args+=(-d "$STREAM_DOMAIN")
    if [[ -n $EMAIL ]]; then
        args+=(--email "$EMAIL")
    else
        args+=(--register-unsafely-without-email)
    fi
    info "通过 Certbot 申请/复用证书（无需停止 Nginx）"
    run_root "${args[@]}" || die "证书配置失败；HTTP 反代仍然可用，请检查 DNS、80/443 端口和 Certbot 日志"

    local nginx_bin
    nginx_bin=$(nginx_binary)
    run_root "$nginx_bin" -t || die "Certbot 完成后 Nginx 配置检查失败"
    reload_nginx
}

uninstall_config() {
    init_privileges
    local nginx_bin=""
    if command -v nginx >/dev/null 2>&1 || [[ -x /usr/sbin/nginx ]]; then
        nginx_bin=$(nginx_binary)
    fi
    if ! run_root test -e "$CONFIG_FILE" && ! run_root test -L "$ENABLED_FILE"; then
        info "没有找到本脚本创建的配置，无需卸载"
        return
    fi

    local backup="${CONFIG_FILE}.removed.$(date +%Y%m%d%H%M%S)"
    run_root test -e "$CONFIG_FILE" && run_root cp -a "$CONFIG_FILE" "$backup"
    run_root rm -f "$ENABLED_FILE" "$CONFIG_FILE"

    if [[ -n $nginx_bin ]] && ! run_root "$nginx_bin" -t; then
        warn "移除后配置检查失败，正在恢复"
        run_root test -e "$backup" && run_root cp -a "$backup" "$CONFIG_FILE"
        run_root ln -sfn "$CONFIG_FILE" "$ENABLED_FILE"
        die "卸载已回滚"
    fi
    [[ -z $nginx_bin ]] || reload_nginx
    info "已移除 Emby 反代配置；备份保留在 ${backup}"
}

main() {
    parse_args "$@"
    if [[ $ACTION == "uninstall" ]]; then
        uninstall_config
        return
    fi
    [[ $NON_INTERACTIVE -eq 1 ]] || interactive_setup
    validate_inputs
    confirm_install

    TEMP_CONFIG=$(mktemp)
    generate_config >"$TEMP_CONFIG"

    if [[ $DRY_RUN -eq 1 ]]; then
        cat "$TEMP_CONFIG"
        [[ $TLS_MODE != "auto" ]] || warn "dry-run 展示的是 Certbot 修改前的 HTTP 配置"
        return
    fi

    init_privileges
    install_dependencies
    check_manual_certificates
    deploy_config "$TEMP_CONFIG"
    [[ $TLS_MODE != "auto" ]] || request_certificate

    local scheme="https"
    [[ $TLS_MODE == "off" ]] && scheme="http"
    info "配置完成：${scheme}://${PUBLIC_DOMAIN}"
    [[ -z $STREAM_DOMAIN ]] || info "推流地址：${scheme}://${STREAM_DOMAIN}"
    info "以后重复运行相同命令即可安全更新配置"
}

main "$@"
