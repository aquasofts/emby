# Emby Nginx 反向代理

一个单文件、可重复执行的 Emby 反向代理安装器。支持普通 Emby、前后端/推流分离、自动 HTTPS、已有证书和纯 HTTP。

与旧版相比，新版不再层层下载脚本和模板，也不会关闭 TLS 校验或为了申请证书停止 Nginx。配置写入后会先执行 `nginx -t`，失败自动恢复旧配置。

重构前的代码按原目录结构保存在 `old/`，只用于查阅，不再参与安装流程。

## 快速开始

推荐先下载再执行，便于检查脚本内容：

```bash
curl -fsSLo install.sh https://raw.githubusercontent.com/aquasofts/emby/main/install.sh
chmod +x install.sh
./install.sh
```

交互模式只需要回答几个问题。常见的 Emby 本机源站可直接使用默认值 `http://127.0.0.1:8096`。

也可以完全使用参数：

```bash
./install.sh \
  --domain media.example.com \
  --upstream http://127.0.0.1:8096 \
  --tls auto \
  --email admin@example.com \
  --yes
```

安装前可预览最终配置，不会修改系统：

```bash
./install.sh \
  --domain media.example.com \
  --upstream http://127.0.0.1:8096 \
  --tls off \
  --dry-run
```

## HTTPS 模式

- `--tls auto`：安装 Certbot，通过正在运行的 Nginx 申请证书并自动续期。域名必须已解析到服务器，公网 80/443 端口必须可访问。
- `--tls manual`：使用已有证书，需要同时提供 `--cert /path/fullchain.pem` 和 `--key /path/privkey.pem`。
- `--tls off`：只监听 HTTP 80 端口，适合上层还有 CDN、负载均衡或内网调试的情况。

自动安装依赖目前明确支持 Debian 12、Ubuntu 22.04 及更新版本。其他发行版可先自行安装 Nginx 和 Certbot，再运行脚本。

## 前后端/推流分离

添加独立推流域名和源站即可：

```bash
./install.sh \
  --domain media.example.com \
  --upstream https://api-origin.example.com \
  --stream-domain stream.example.com \
  --stream-upstream https://stream-origin.example.com \
  --tls auto \
  --email admin@example.com \
  --yes
```

主站文本响应中的推流源站地址会被改写为公开推流域名；视频响应不会进入内存缓冲。manual 模式还可用 `--stream-cert` 和 `--stream-key` 为推流域名指定另一套证书，省略时复用主域名证书。

## 更新与卸载

使用新参数重新运行脚本即可更新。安装器会备份现有配置、原子替换、检查并重载；任何一步失败都会回滚。

仅移除本项目创建的 Nginx 配置：

```bash
./install.sh --uninstall
```

卸载不会删除 Nginx、Certbot、证书或其他站点，也不会清空 `/etc/nginx`。

## 工作原理

安装器只管理两个固定路径：

- `/etc/nginx/sites-available/emby-proxy`
- `/etc/nginx/sites-enabled/emby-proxy`

它会校验域名、源站、端口和证书路径，生成支持 WebSocket 和长时间媒体连接的 Nginx 配置，然后依次执行备份、写入、`nginx -t` 和 reload。自动 HTTPS 使用 Certbot 的 Nginx 插件，不需要中断已有服务。

查看全部参数：

```bash
./install.sh --help
```

## 开发测试

测试只使用 `--dry-run`，不会接触系统 Nginx：

```bash
bash -n install.sh tests/test.sh
bash tests/test.sh
```

本项目仅供合法的自建媒体服务使用。
