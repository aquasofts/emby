<h1>一键反代emby脚本</h1>
运行本脚本将会自动对您的自建emby服务器进行反代，并自动配置nginx，实现emby服务器的远程访问，随时随地查看您的媒体。

### 使用方法
一键脚本：

`wget -N --no-check-certificate https://raw.githubusercontent.com/aquasofts/emby/main/install.sh && chmod +x install.sh && ./install.sh`

### 啰嗦一句

1.安装nginx过程可能会有点慢，请耐心等待。所有选项都输入"y"即可。

2.本脚本需要全新系统安装环境，非全新环境可能会导致脚本无法使用

3.脚本未加密。里面每个功能都注释的很清楚，不存在任何安全问题，请放心使用。脚本写的很烂有大佬愿意可以提交修改！~

4.本脚基本仅在Ubuntu22、Debian12进行测试。

5.本脚本仅供学习交流使用，不提供任何资源，请勿用于非法用途，否则后果自负。

6.感谢 [x-ui](https://github.com/FranzKafkaYu/x-ui/) [acme1key.sh](https://github.com/tlxhl/acme-1key/) 项目中的acme相关代码

7.期待有大佬可以把端口申请证书修改为nginx模式申请证书，这样可以解决端口占用问题，我技术力不够。。。

8.如果此脚本对您有帮助，不妨点一个star支持一下，让更多人受到帮助

9.如果遇到如图所示界面，直接回车即可

![image](https://github.com/aquasofts/emby/blob/main/image.png)

