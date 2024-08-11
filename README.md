<h1>一键反代emby脚本</h1>
运行本脚本将会自动对您的自建emby服务器进行反代，并自动配置nginx，实现emby服务器的远程访问，随时随地查看您的媒体。

### 使用方法
一键脚本：

`wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/emby.sh && chmod +x emby.sh && ./emby.sh`

### 啰嗦一句
1.脚本未加密。里面每个功能都注释的很清楚，不存在任何安全问题，请放心使用。脚本写的很烂有大佬愿意可以提交修改！~

2.本脚基本尽在Ubuntu22、Debian12进行测试。

3.由于我的技术力有限，目前只写出了开放80端口的http协议，未来可能会更新通过acme申请脚本后实现https协议。

3.本脚本仅供学习交流使用，不提供任何资源，请勿用于非法用途，否则后果自负。