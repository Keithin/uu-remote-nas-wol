# UU远程-NAS唤醒助手

在常在线的 NAS 上通过 Docker 运行辅助客户端，即可用它唤醒同一局域网内已关机的 Windows 电脑。出门后，在官方网易 UU 远程 App 里选择目标电脑并点击「远程开机」，网易云端会把请求交给 NAS 上的客户端，由它在局域网内发送 Wake-on-LAN 唤醒包。

已在极空间 Z4（x86_64）上实测。官方 App 可远程关机并重新启动同一局域网中的 Windows 电脑，NAS 日志记录了收到唤醒指令并发包。容器已设置 `unless-stopped`，整机重启后的端到端开机尚未验收。本仓库整理了该部署方式，使用相对路径并合并了构建和运行配置。公开模板已通过 Compose 配置校验。

![极空间 Z4 在网易 UU 远程的设备列表中显示在线](docs/images/uu-remote-nas-wol.png)

## 准备

- x86_64 NAS，已启用 Docker Engine 与 Compose。
- NAS 和目标 Windows 电脑处在同一局域网。目标电脑已启用 WoL，关机后网卡仍可接收唤醒包。
- NAS 能访问 Docker 镜像仓库、Ubuntu 软件源、crates.io 和网易服务。
- [uu-remote-linux](https://github.com/VallierDev/uu-remote-linux) 是第三方客户端。无桌面模式仍包含终端、文件传输及端口映射能力。请只挂载本项目专用目录，保管好扫码二维码和 `config/` 中的登录信息。

## 部署

在具备 Docker 权限的 NAS 终端执行。克隆本仓库后，进入仓库目录，再执行：

```sh
git clone https://github.com/VallierDev/uu-remote-linux.git source
git -C source checkout --detach fe052cdca7ad90d1ab7c27d031036b1071869070
mkdir -p output data
mkdir -m 700 -p config
docker compose run --rm builder
docker compose run --rm uu-wol login --no-gui
```

构建会运行四项 WoL 单元测试，再将客户端写入 `output/`。固定提交包含 [辅助设备注册修复](https://github.com/VallierDev/uu-remote-linux/pull/209)。首次登录时，用官方 UU 远程 App 扫描终端里的二维码，授权目标电脑所用的 UU 账号。登录成功后启动服务：

```sh
docker compose up -d uu-wol
docker compose ps
```

容器以宿主网络运行，以便读取真实局域网接口并发送广播。启动时会检查和安装运行依赖。Docker 引擎需要能在 NAS 开机后自行启动，容器的重启策略才会生效。

## 验收

1. 查看 `docker compose logs uu-wol`，确认客户端上线且 `WOL helper: LAN info reported` 返回 HTTP 200、业务码 0。
2. 在官方 UU 远程中确认 NAS 可作为目标电脑的辅助开机设备。
3. 保存工作并正常关机。从局域网外在官方 App 点击目标电脑的「远程开机」。确认日志出现 `wake_on_lan` 和 `magic packet sent`，并实际连上已启动的电脑。
4. 重启容器后再试一次，验证原绑定仍可用。若要确认 NAS 开机自启，等一次计划内重启后再重复验收。

`docker compose stop uu-wol` 可停止服务，`docker compose down` 可移除该项目的容器。将 `config/` 私下保存可保留登录配置。

本仓库使用 GPL-3.0。网易 UU 远程和极空间是各自厂商的产品。本方案使用社区客户端，其兼容性取决于网易服务和目标网络。 [上游 NAS 部署文档](https://github.com/VallierDev/uu-remote-linux/blob/fe052cdca7ad90d1ab7c27d031036b1071869070/docs/deploy-nas-docker.md)
