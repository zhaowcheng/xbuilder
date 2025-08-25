FROM ghcr.io/loong64/debian:trixie

# 设置代理，否则下载源码和缓存包都会很慢。
ENV HTTP_PROXY=http://172.17.0.1:7890
ENV HTTPS_PROXY=http://172.17.0.1:7890
ENV NO_PROXY=localhost,127.0.0.1
ENV http_proxy=http://172.17.0.1:7890
ENV https_proxy=http://172.17.0.1:7890
ENV no_proxy=localhost,127.0.0.1
# 设置 nix 命令路径，由于 docker build 是用 bash -c 的方式执行命令会找不到这些命令。
ENV PATH=/nix/var/nix/profiles/default/bin:$PATH

# 设置容器启动默认 shell 为 bash，并自动启动 nix-daemon 进程。
CMD ["/bin/bash", "-c", "sudo -i nix-daemon & exec /bin/bash"]

# 后续步骤默认 shell 为 bash。
SHELL ["/bin/bash", "-c"]

# 更换为国内镜像源
RUN cd /etc/apt/sources.list.d/ && mv debian.sources debian.sources.backup
RUN cd /etc/apt/sources.list.d/ && \
    echo "Types: deb" > debian.sources && \
    echo "URIs: http://mirrors.aliyun.com/debian" >> debian.sources && \
    echo "Suites: trixie trixie-updates" >> debian.sources && \
    echo "Components: main" >> debian.sources && \
    echo "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg" >> debian.sources

# 安装常用包
RUN apt update
RUN apt install -y sudo vim git wget 

# 创建用户
RUN useradd -m -s /bin/bash xflow
RUN echo "xflow    ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换用户和工作目录
USER xflow
WORKDIR /home/xflow

# 下载 nix 安装包（v2.28.3）
RUN wget https://github.com/DeterminateSystems/nix-installer/releases/download/v3.5.2/nix-installer-aarch64-linux -O nix-installer

# 安装 nix
RUN chmod +x nix-installer
RUN sudo -E ./nix-installer install linux --init none --no-confirm --extra-conf "filter-syscalls = false"
RUN echo "substituters = https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org" | sudo tee -a /etc/nix/nix.custom.conf
RUN rm -f nix-installer

# 锁定 nixpkgs 版本，请保持与 flake.nix 中的版本保持一致。
RUN sudo -i nix registry add --registry /etc/nix/registry.json nixpkgs "github:loongson-community/nixpkgs/d963e658fd06ad8ca24404ed3faf1375856ac598"

# 配置 postgres 编译环境
RUN mkdir flakes
COPY flake.nix flakes/
RUN (sudo -i nix-daemon &) && sleep 5 && nix develop flakes/#postgres -c echo postgres is ok

# 验证 postgres 编译环境
RUN mkdir code
RUN wget https://github.com/postgres/postgres/archive/refs/tags/REL_17_6.tar.gz -P code/
RUN cd code && tar xvf REL_17_6.tar.gz
WORKDIR /home/xflow/code/postgres-REL_17_6
RUN sed -i 's/$(SHELL)/$(shell echo $$SHELL)/g' src/test/regress/GNUmakefile
RUN sed -i '351a system_or_bail("sync");' src/bin/pg_basebackup/t/010_pg_basebackup.pl
RUN sed -i '85a\        system_or_bail("sync");' src/bin/pg_ctl/t/001_start_stop.pl
RUN (sudo -i nix-daemon &) && sleep 5 && nix develop ~/flakes/#postgres -c ./configure \
        --prefix=`pwd`/install \
        --enable-nls \
        --enable-debug \
        --enable-cassert \
        --enable-tap-tests \
        --enable-depend \
        --enable-coverage \
        --enable-profiling \
        --enable-dtrace \
        --enable-injection-points \
        --with-perl \
        --with-python \
        --with-tcl \
        --with-llvm \
        --with-lz4 \
        --with-zstd \
        --with-openssl \
        --with-gssapi \
        --with-ldap \
        --with-pam \
        --with-systemd \
        --with-uuid=ossp \
        --with-libxml \
        --with-libxslt \
        --with-selinux \
        --with-icu
RUN (sudo -i nix-daemon &) && sleep 5 && nix develop ~/flakes/#postgres -c make world -j`nproc`
RUN (sudo -i nix-daemon &) && sleep 5 && nix develop ~/flakes/#postgres -c make check-world -j`nproc`
WORKDIR /home/xflow
RUN rm -rf code
