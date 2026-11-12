# UU远程-NAS唤醒助手

让常在线的 NAS 成为网易 UU 远程开机的辅助设备。在 NAS 上用 Docker 运行无桌面客户端后，即使人在外面，也能在官方 UU 远程里选中已关机的 Windows 电脑，点「远程开机」。网易云端把指令交给 NAS，由 NAS 在同一局域网内发出 Wake-on-LAN 唤醒包。

## 实际效果

**1. NAS 在线待命。** 极空间 Z4 的 Docker 容器登录后，在 UU 远程的「我的设备」中显示在线。它负责接收开机指令，并在局域网内唤醒目标电脑。

![极空间 Z4 部署无桌面客户端后，在 UU 远程设备列表中显示在线](docs/images/uu-remote-nas-wol.png)

**2. 对目标电脑发起远程开机。** 选中显示离线的 Windows 电脑，点击它的「远程开机」。界面显示「开机指令已发送」和倒计时，此时正在等待电脑上线。

![目标 Windows 电脑处于离线状态，UU 远程显示开机指令已发送](docs/images/uu-remote-wake-in-progress.png)

已在极空间 Z4（x86_64）上实测远程关机和开机。目标电脑成功上线，NAS 日志也记录了收到指令并发出唤醒包。容器已设置 `unless-stopped`。极空间 Z4 整机重启后复测通过，仍可在官方 UU 远程中一键唤醒目标电脑。本仓库的 Compose 模板使用相对路径，已通过配置校验，尚未在另一台 NAS 上完整部署。

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

## 极空间 Z4 开机自启

开机时先等存储池挂载，确认 Docker 数据目录以及 UU 容器的程序和登录配置可读，再启动 Docker 引擎。Compose 已为 `uu-wol` 设置 `restart: unless-stopped`，引擎启动后会恢复之前在运行的容器。如果曾手动停止该容器，请先用 `docker compose up -d uu-wol` 恢复运行。

如果 Z4 已有可用的引擎自启流程，直接按下文复测即可。如果你的固件使用 systemd 管理 Docker，且需要补上开机启动，可以参考下面的配置。先用 `sudo systemctl cat docker.service` 确认服务名，用 `sudo docker info --format '{{.DockerRootDir}}'` 查 Docker 数据目录，并用 `findmnt -T <目录>` 分别确认数据目录和 Compose 挂载目录所在的真实挂载点。

用 `sudo systemctl edit docker.service` 添加 drop-in。以下路径都是占位符，必须换成你自己的路径。若几个目录位于同一挂载点，按实际情况填写。

```ini
[Unit]
RequiresMountsFor=/mnt/docker-pool /mnt/uu-pool

[Service]
ExecStartPre=/bin/sh -ec 'for attempt in $(seq 1 60); do if mountpoint -q /mnt/docker-pool && mountpoint -q /mnt/uu-pool && test -d /mnt/docker-pool/docker/containers && test -x /mnt/uu-pool/uu-wol/output/uuremote-server && test -s /mnt/uu-pool/uu-wol/config/config.json; then exit 0; fi; sleep 5; done; echo "Docker storage paths are not ready" >&2; exit 1'
```

`RequiresMountsFor` 声明挂载依赖，启动前检查再确认预期目录和文件确实可用。示例最多等待约 5 分钟，超时会让这次 Docker 启动失败，避免在存储未就绪时继续启动。这个 drop-in 作用于整个 Docker 引擎，其他容器也会一起等待。如果 UU 的路径经由 ZOS 的挂载映射访问，检查路径应使用 Compose 实际绑定的目录。

```sh
sudo systemd-analyze verify docker.service
sudo systemctl daemon-reload
sudo systemctl enable docker.service
systemctl is-enabled docker.service
systemctl show docker.service -p DropInPaths -p RequiresMountsFor
```

这些命令设置并读回自启配置，无需立即重启引擎。ZOS 可能另有引擎启动流程，重启后的引擎状态和唤醒实测应一起检查。

## 验收

1. 查看 `docker compose logs uu-wol`，确认客户端上线且 `WOL helper: LAN info reported` 返回 HTTP 200、业务码 0。
2. 在官方 UU 远程中确认 NAS 可作为目标电脑的辅助开机设备。
3. 保存工作并正常关机。从局域网外在官方 App 点击目标电脑的「远程开机」。确认日志出现 `wake_on_lan` 和 `magic packet sent`，并实际连上已启动的电脑。
4. 在 NAS 计划内重启前确认 `uu-wol` 正在运行。NAS 开机后，先别手动启动或重启 Docker，运行 `systemctl is-active docker.service` 和 `docker compose ps uu-wol`，确认引擎已启动、容器已恢复。若使用上面的自启配置，同时读回 `systemctl is-enabled docker.service` 和 drop-in。
5. 确认容器沿用原来的扫码绑定并成功上报局域网信息。让目标 Windows 电脑正常关机，再从局域网外用官方 UU App 点击「远程开机」。看到 NAS 收到指令、发出唤醒包，并实际连上开机后的电脑，才算重启后验收通过。
6. 如果引擎没起来，先看 `sudo journalctl -b -u docker.service --no-pager` 和存储挂载状态。如果引擎已运行但容器没恢复，检查 `docker compose ps -a uu-wol`、容器重启策略和 `docker compose logs uu-wol`。

`docker compose stop uu-wol` 可停止服务，`docker compose down` 可移除该项目的容器。将 `config/` 私下保存可保留登录配置。

## 致谢

感谢 `uu-remote-linux` 的维护者和贡献者提供 Linux 无桌面客户端、NAS Docker 部署文档，以及辅助开机设备的注册修复。本仓库基于这些工作整理了 NAS 部署和实机验收步骤。 [上游项目](https://github.com/VallierDev/uu-remote-linux) · [上游 NAS 部署文档](https://github.com/VallierDev/uu-remote-linux/blob/fe052cdca7ad90d1ab7c27d031036b1071869070/docs/deploy-nas-docker.md) · [注册修复 PR](https://github.com/VallierDev/uu-remote-linux/pull/209)

## 免责声明

本仓库是独立的社区项目，未经网易官方授权或背书，与网易公司及网易 UU 远程团队无隶属或合作关系。文中使用「网易」和「UU 远程」仅用于指称相关产品，相关商标归各自权利人所有。

本仓库按 GPL-3.0 提供。辅助开机依赖网易 UU 远程服务、上游客户端和本地网络环境。网易服务或客户端更新可能影响兼容性，本项目不保证持续可用。
