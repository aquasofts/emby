<h1>One-Click Reverse Proxy Emby Script</h1>

[简体中文](https://github.com/aquasofts/emby/blob/main/README.md) | [English](https://github.com/aquasofts/emby/blob/main/README_EN.md)

Running this script will automatically set up a reverse proxy for your self-hosted Emby server and configure Nginx for remote access to your Emby server, allowing you to view your media anytime, anywhere.

### Usage
One-click script:

`wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/install.sh && chmod +x install.sh && ./install.sh`

For machines in mainland China, you can use Gitee (note that versions may not be synchronized, maintained as needed):

`wget -N --no-check-certificate https://gitee.com/aquasoft/emby/raw/main/install.sh && chmod +x install.sh && ./install.sh`

### Major Update Log

2024-08-10

· Project officially launched

2024-08-12

· Added automatic certificate application for Emby ports, no manual application needed.

· Initial script completion

2024-09-07

· Updated support for the front-end and back-end separated version of the Emby server

### How to Uninstall

I’ve been a bit busy lately, so the uninstallation script will be updated as needed. Before the uninstallation script is released, please manually delete the relevant files.

· Please delete files unrelated to your project in the following directories:

`/etc/nginx/sites-available`

`/etc/nginx/sites-enabled`

· Or directly execute the Nginx uninstallation script:

`wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/uninstallnginx/main/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh`

· Then delete files unrelated to your project in the following directories. If no other projects are deployed, you can delete the entire folder:

`/root/.acme.sh`

`/root/cert`

### A Few Words

The installation process of Nginx may be a bit slow, please be patient. Enter “y” for all options.

This script requires a fresh system installation environment. Non-fresh environments may cause the script to be unusable.

The script is not encrypted. Every function is clearly commented, and there are no security issues. Please feel free to use it. The script is poorly written, so if any experts are willing, feel free to submit modifications!

This script has only been tested on Ubuntu 22 and Debian 12.

This script is for learning and communication purposes only. No resources are provided. Do not use it for illegal purposes, otherwise, you will be responsible for the consequences.

Thanks to the x-ui and acme1key.sh projects for the acme-related code.

I hope some experts can modify the port certificate application to Nginx mode to solve the port occupation problem. My technical skills are not enough…

If this script helps you, please give it a star to support it and help more people.

If you encounter the interface shown in the picture, just press "y" to continue.

![image](https://github.com/aquasofts/emby/blob/main/image.png)