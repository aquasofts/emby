<h1>One-Click Reverse Proxy Emby Script</h1>

[简体中文](https://github.com/aquasofts/emby/blob/main/README.md) | [English](https://github.com/aquasofts/emby/blob/main/README_EN.md)

Running this script will automatically reverse proxy your self-hosted Emby server and automatically configure Nginx, enabling remote access to your Emby server, allowing you to access your media anytime, anywhere.

### Usage
One-click script:

```
wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/install.sh && chmod +x install.sh && ./install.sh
```

### Major Update Logs

2024-08-10

· Project officially started

2024-08-12

· Added automatic certificate generation for Emby’s port, eliminating the need for manual certificate application.

· Script initial version completed

2024-09-07

· Added support for front-end and back-end separated versions of Emby server

2024-09-30

· Updated functionality to only rewrite links in the front-end and back-end separated versions of Emby server, addressing access issues when no domain is specified.

### How to Uninstall

I've been busy lately, so the uninstall script will be updated whenever possible. Before the official uninstall script is released, please manually remove the related files.

· Delete unrelated files in the following directories:

`/etc/nginx/sites-available`

`/etc/nginx/sites-enabled`

· Or execute the Nginx uninstall script:

```
wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/uninstallnginx/main/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
```

· After that, delete the unrelated files in the following directories. If no other projects are deployed, you can directly delete the entire folder:

`/root/.acme.sh`

`/root/cert`

### A Few Notes

1. The Nginx installation process may be slow, so please be patient. For all options, just enter "y".

2. This script requires a fresh system installation. Non-fresh systems may cause the script to fail.

3. The script is not encrypted. Every function is well-documented, and there are no security issues. Please feel free to use it. The script is poorly written, so if anyone wants to improve it, feel free to submit modifications!

4. This script has been tested only on Ubuntu 22 and Debian 12.

5. This script is for learning and communication purposes only. No resources are provided, and please do not use it for illegal purposes; any consequences are your own responsibility.

6. Thanks to [x-ui](https://github.com/FranzKafkaYu/x-ui/) and [acme1key.sh](https://github.com/tlxhl/acme-1key/) projects for the acme-related code.

7. I hope someone can modify the certificate generation for Nginx mode to solve the port occupation issue. My skills aren't sufficient...

8. If this script has been helpful to you, consider giving it a star to help others benefit from it.

9. If you encounter a screen like the one shown, just press Enter.

![image](https://github.com/aquasofts/emby/blob/main/image.png)