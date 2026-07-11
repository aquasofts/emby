#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INSTALLER="${ROOT_DIR}/install.sh"
passed=0

assert_contains() {
    local text=$1
    local expected=$2
    [[ $text == *"$expected"* ]] || {
        printf '断言失败，缺少：%s\n' "$expected" >&2
        exit 1
    }
    passed=$((passed + 1))
}

assert_not_contains() {
    local text=$1
    local unexpected=$2
    [[ $text != *"$unexpected"* ]] || {
        printf '断言失败，不应包含：%s\n' "$unexpected" >&2
        exit 1
    }
    passed=$((passed + 1))
}

http_config=$("$INSTALLER" --dry-run --yes \
    --domain media.example.com \
    --upstream http://127.0.0.1:8096 \
    --tls off)
assert_contains "$http_config" "server_name media.example.com;"
assert_contains "$http_config" "proxy_pass http://127.0.0.1:8096;"
assert_contains "$http_config" 'proxy_set_header Upgrade $http_upgrade;'
assert_not_contains "$http_config" "ssl_certificate"

manual_config=$("$INSTALLER" --dry-run --yes \
    --domain media.example.com \
    --upstream https://origin.example.com \
    --stream-domain stream.example.com \
    --stream-upstream https://stream-origin.example.com:443 \
    --tls manual \
    --cert /cert/media.pem \
    --key /cert/media.key \
    --stream-cert /cert/stream.pem \
    --stream-key /cert/stream.key)
assert_contains "$manual_config" 'ssl_protocols TLSv1.2 TLSv1.3;'
assert_contains "$manual_config" 'sub_filter "http://stream-origin.example.com:443" "https://stream.example.com";'
assert_contains "$manual_config" 'sub_filter_types text/css text/javascript application/javascript application/json application/xml;'
assert_contains "$manual_config" 'ssl_certificate "/cert/stream.pem";'
assert_contains "$manual_config" "server_name stream.example.com;"

auto_config=$("$INSTALLER" --dry-run --yes \
    --domain media.example.com \
    --upstream http://127.0.0.1:8096 \
    --tls auto 2>/dev/null)
assert_contains "$auto_config" "listen 80;"
assert_not_contains "$auto_config" "listen 443 ssl;"

if "$INSTALLER" --dry-run --yes --domain invalid --upstream http://127.0.0.1:8096 --tls off >/dev/null 2>&1; then
    printf '无效域名没有被拒绝\n' >&2
    exit 1
fi
passed=$((passed + 1))

if "$INSTALLER" --dry-run --yes --domain media.example.com --upstream http://host/path --tls off >/dev/null 2>&1; then
    printf '带路径的源站没有被拒绝\n' >&2
    exit 1
fi
passed=$((passed + 1))

# 归档应与重构前的 Git 内容一致。apply_patch 会为少数原本无末尾换行的
# 文本补一个换行，因此也接受“仅多一个末尾换行”的情况。
archive_count=0
while IFS= read -r path; do
    expected=$(git -C "$ROOT_DIR" rev-parse "HEAD:${path}")
    actual=$(git hash-object --no-filters "${ROOT_DIR}/old/${path}")
    if [[ $expected != "$actual" ]]; then
        trimmed=$(head -c -1 "${ROOT_DIR}/old/${path}" | git hash-object --stdin)
        [[ $expected == "$trimmed" ]] || {
            printf '旧版归档内容不一致：%s\n' "$path" >&2
            exit 1
        }
    fi
    archive_count=$((archive_count + 1))
done < <(git -C "$ROOT_DIR" ls-tree -r --name-only HEAD -- file options sh)
[[ $archive_count -eq 36 ]] || {
    printf '旧版归档文件数错误：%d\n' "$archive_count" >&2
    exit 1
}
passed=$((passed + 1))

printf '通过 %d 项测试。\n' "$passed"
