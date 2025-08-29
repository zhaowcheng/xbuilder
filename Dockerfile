FROM m.daocloud.io/docker.io/library/debian:bookworm AS amd64-image
FROM m.daocloud.io/docker.io/library/debian:bookworm AS arm64-image
FROM m.daocloud.io/docker.io/library/debian:bookworm AS mips64le-image
FROM ghcr.io/loong64/debian:trixie AS loong64-image
FROM ${TARGETARCH}-image AS xflow-image

# 设置代理，否则下载源码和缓存包都会很慢。
ENV HTTP_PROXY=http://172.17.0.1:7890
ENV HTTPS_PROXY=http://172.17.0.1:7890
ENV NO_PROXY=localhost,127.0.0.1,cache.nix4loong.cn
ENV http_proxy=http://172.17.0.1:7890
ENV https_proxy=http://172.17.0.1:7890
ENV no_proxy=localhost,127.0.0.1,cache.nix4loong.cn
# 设置 nix 命令路径，由于 docker build 是用 bash -c 的方式执行命令会找不到这些命令。
ENV PATH=/nix/var/nix/profiles/default/bin:$PATH

# 后续步骤默认 shell 为 bash。
SHELL ["/bin/bash", "-c"]

# 更换为国内镜像源
RUN cd /etc/apt/sources.list.d/ && mv debian.sources debian.sources.backup
## loongarch64 架构在 debian 社区属于 ports 级支持，所以使用 debian-ports 源。
RUN cd /etc/apt/sources.list.d/ && \
    if [ `uname -m` = loongarch64 ]; then \
      echo "Types: deb" > debian.sources && \
      echo "URIs: http://mirrors.aliyun.com/debian-ports" >> debian.sources && \
      echo "Suites: sid unreleased" >> debian.sources && \
      echo "Components: main" >> debian.sources && \
      echo "Signed-By: /usr/share/keyrings/debian-ports-archive-keyring.gpg" >> debian.sources; \
    else \
      echo "Types: deb" > debian.sources && \
      echo "URIs: http://mirrors.aliyun.com/debian" >> debian.sources && \
      echo "Suites: bookworm bookworm-updates" >> debian.sources && \
      echo "Components: main" >> debian.sources && \
      echo "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg" >> debian.sources; \
    fi

# 安装常用包
RUN apt update
RUN apt install -y sudo vim git wget 

# 设置 vim 默认编码
RUN echo set encoding=utf-8 >> /etc/vim/vimrc

# 创建普通用户，用来跑 postgres 回归测试。
RUN useradd -m -s /bin/bash xflow
RUN echo "xflow    ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换工作目录到 xflow 用户的 home。
WORKDIR /home/xflow

# 下载并安装 nix，x86_64 和 aarch64 的 nix 版本为 2.28.3，loongarch64 为 2.28.4。
RUN if [ `uname -m` = x86_64 ]; then \
      wget https://github.com/DeterminateSystems/nix-installer/releases/download/v3.5.2/nix-installer-x86_64-linux -O nix-installer; \
    elif [ `uname -m` = aarch64 ]; then \
      wget https://github.com/DeterminateSystems/nix-installer/releases/download/v3.5.2/nix-installer-aarch64-linux -O nix-installer; \
    elif [ `uname -m` = loongarch64 ]; then \
      wget https://download.nix4loong.cn/nix-installer/latest/nix-installer-loongarch64-linux -O nix-installer; \
    else \
      echo "ERROR: Unsupported architecture: `uname -m`" && exit 1; \
    fi && \
    chmod +x nix-installer && \
    ./nix-installer install linux --init none --no-confirm --extra-conf "filter-syscalls = false" && \
    rm -f nix-installer
## 更换 nix 二进制缓存源为国内源，loongarch64 的安装包默认配置了缓存源为 cache.nix4loong.cn，所以无需替换。
RUN if [ `uname -m` != loongarch64 ]; then \
      echo "substituters = https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org" >> /etc/nix/nix.custom.conf; \
    fi
## 锁定 nixpkgs 版本，请保持与 flake.nix 中的版本保持一致。
RUN if [ `uname -m` = loongarch64 ]; then \
      nix registry add --registry /etc/nix/registry.json nixpkgs "github:loongson-community/nixpkgs/64275dcdf675155d24d08ba72e1382c1ffe38c2b"; \
    else \
      nix registry add --registry /etc/nix/registry.json nixpkgs "github:NixOS/nixpkgs/11cb3517b3af6af300dd6c055aeda73c9bf52c48"; \
    fi

# 配置 postgres 编译环境
RUN mkdir flakes
COPY flake.nix flakes/
RUN nix develop flakes/#postgres -c echo postgres-dev-env is ok
RUN chown -R xflow: /home/xflow/flakes

# 验证 postgres 编译环境
# postgres 不支持 root 用户运行，所以要切换到普通用户进行测试。
# 通常 make 内建变量 SHELL 的值为 `/bin/sh`，而 nix 中的 make 为 `sh`，这会导致 pg_regress 程序失败，所以修改 src/test/regress/GNUmakefile 直接取当前环境变量 SHELL。
# 在 postgres 启用了 --enable-profiling 编译参数的情况下，在 docker+nix 环境中会出现性能数据文件 gmon.out 刷盘不及时导致部分测试脚本失败，所以增加一个 sync 命令强制刷盘避免该问题。
# postgres 不支持 loongarch64 架构的 llvm，所以该架构上不带 --with-llvm 参数。
# 普通用户使用 nix 需要先启动 nix-daemon 进程，增加 sleep 是为了等到该进程启动完成后再调用 nix 命令。
USER xflow
RUN mkdir code
RUN cd code && \
    wget https://github.com/postgres/postgres/archive/refs/tags/REL_17_6.tar.gz && \
    tar xvf REL_17_6.tar.gz && \
    cd postgres-REL_17_6 && \
    sed -i 's/$(SHELL)/$(shell echo $$SHELL)/g' src/test/regress/GNUmakefile && \
    sed -i '351a system_or_bail("sync");' src/bin/pg_basebackup/t/010_pg_basebackup.pl && \
    sed -i '85a\        system_or_bail("sync");' src/bin/pg_ctl/t/001_start_stop.pl && \
    (sudo -i nix-daemon &) && sleep 5 && \
    if [ `uname -m` != loongarch64 ]; then \
      nix develop /home/xflow/flakes/#postgres -c ./configure --prefix=`pwd`/install --enable-nls --enable-debug --enable-cassert --enable-tap-tests --enable-depend --enable-coverage --enable-profiling --enable-dtrace --enable-injection-points --with-perl --with-python --with-tcl --with-llvm --with-lz4 --with-zstd --with-openssl --with-gssapi --with-ldap --with-pam --with-systemd --with-uuid=ossp --with-libxml --with-libxslt --with-selinux --with-icu; \
    else \
      nix develop /home/xflow/flakes/#postgres -c ./configure --prefix=`pwd`/install --enable-nls --enable-debug --enable-cassert --enable-tap-tests --enable-depend --enable-coverage --enable-profiling --enable-dtrace --enable-injection-points --with-perl --with-python --with-tcl --with-lz4 --with-zstd --with-openssl --with-gssapi --with-ldap --with-pam --with-systemd --with-uuid=ossp --with-libxml --with-libxslt --with-selinux --with-icu; \
    fi && \
    nix develop /home/xflow/flakes/#postgres -c make world -j`nproc` && \
    nix develop ~/flakes/#postgres -c make check-world -j`nproc` && \
    cd ~ && rm -rf code/*

# 切换回 root 用户
USER root
# 设置容器启动默认 shell 为 bash，并自动启动 nix-daemon 进程。
CMD ["/bin/bash", "-c", "nix-daemon & exec /bin/bash"]