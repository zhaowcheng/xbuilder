FROM m.daocloud.io/docker.io/library/debian:bookworm

# 设置 nix 命令路径，由于 docker build 是用 bash -c 的方式执行命令会找不到这些命令。
ENV PATH=/nix/var/nix/profiles/default/bin:$PATH

# 后续步骤默认 shell 为 bash。
SHELL ["/bin/bash", "-c"]

# 更换为国内镜像源
RUN cd /etc/apt/sources.list.d/ && \
    echo "Types: deb" > debian.sources && \
    echo "URIs: http://mirrors.aliyun.com/debian" >> debian.sources && \
    echo "Suites: bookworm bookworm-updates" >> debian.sources && \
    echo "Components: main" >> debian.sources && \
    echo "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg" >> debian.sources

# 安装常用包
RUN apt update
RUN apt install -y sudo wget 

# 创建普通用户，用来跑 postgres 回归测试。
RUN useradd -m -s /bin/bash xbuilder
RUN echo "xbuilder    ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换工作目录到 xbuilder 用户的 home。
WORKDIR /home/xbuilder

# 下载并安装 nix 2.28.3。
RUN wget https://ghfast.top/https://github.com/DeterminateSystems/nix-installer/releases/download/v3.5.2/nix-installer-x86_64-linux -O nix-installer && \
    chmod +x nix-installer && \
    ./nix-installer install linux --init none --no-confirm --extra-conf "filter-syscalls = false" && \
    rm -f nix-installer
## 更换 nix 二进制缓存源为国内源。
RUN echo "substituters = https://cache.nix4loong.cn https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org https://nix-community.cachix.org" >> /etc/nix/nix.custom.conf
## 增加额外支持的平台。
RUN echo extra-platforms = aarch64-linux loongarch64-linux mips64el-linux >> /etc/nix/nix.custom.conf
## 增加 loongarch64 支持。
RUN echo extra-system-features = gccarch-la64v1.0 gccarch-loongarch64 >> /etc/nix/nix.custom.conf
## 锁定 nixpkgs 版本，请保持与 flake.nix 中的 nixpkgs-nix 版本保持一致。
RUN nix registry add --registry /etc/nix/registry.json nixpkgs "github:NixOS/nixpkgs/11cb3517b3af6af300dd6c055aeda73c9bf52c48"

# 切换到普通用户去配置和验证 nix 环境。
USER xbuilder
RUN mkdir flakes
COPY flake.nix flakes/
COPY scripts/nixbuild.sh ./
RUN chmod +x nixbuild.sh
RUN ./nixbuild.sh x86_64 postgres
RUN ./nixbuild.sh aarch64 postgres
RUN ./nixbuild.sh loongarch64 postgres
RUN ./nixbuild.sh mips64el postgres

# 切换回 root 用户
USER root
# 设置容器启动默认 shell 为 bash，并自动启动 nix-daemon 进程。
CMD ["/bin/bash", "-c", "nix-daemon & exec /bin/bash"]
