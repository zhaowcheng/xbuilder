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
RUN echo "substituters = https://cache.nix4loong.cn https://mirror.sjtu.edu.cn/nix-channels/store https://cache.nixos.org" >> /etc/nix/nix.custom.conf
## 增加额外支持的平台。
RUN echo extra-platforms = aarch64-linux loongarch64-linux mips64el-linux >> /etc/nix/nix.custom.conf
## 增加 loongarch64 支持。
RUN echo extra-system-features = gccarch-la64v1.0 gccarch-loongarch64 >> /etc/nix/nix.custom.conf
## 锁定 nixpkgs 版本，请保持与 flake.nix 中的 nixpkgs-nix 版本保持一致。
RUN nix registry add --registry /etc/nix/registry.json nixpkgs "github:NixOS/nixpkgs/11cb3517b3af6af300dd6c055aeda73c9bf52c48"

# 配置 postgres 编译环境
RUN mkdir flakes
COPY flake.nix flakes/
RUN nix develop flakes/#devShells.x86_64-linux.postgres -c echo postgres-x86_64 is ok
RUN nix develop flakes/#devShells.aarch64-linux.postgres -c echo postgres-aarch64 is ok
RUN nix develop flakes/#devShells.loongarch64-linux.postgres -c echo postgres-loongarch64 is ok
RUN nix develop flakes/#devShells.mips64el-linux.postgres -c echo postgres-mips64el is ok
RUN chown -R xbuilder: /home/xbuilder/flakes

# 验证 postgres 编译环境
# postgres 不支持 root 用户运行，所以要切换到普通用户进行测试。
# 通常 make 内建变量 SHELL 的值为 `/bin/sh`，而 nix 中的 make 为 `sh`，这会导致 pg_regress 程序失败，所以修改 src/test/regress/GNUmakefile 直接取当前环境变量 SHELL。
# 在 postgres 启用了 --enable-profiling 编译参数的情况下，在 docker+nix 环境中会出现性能数据文件 gmon.out 刷盘不及时导致部分测试脚本失败，所以增加一个 sync 命令强制刷盘避免该问题。
# postgres 不支持 loongarch64 架构的 llvm，所以该架构上不带 --with-llvm 参数。
# 普通用户使用 nix 需要先启动 nix-daemon 进程，增加 sleep 是为了等到该进程启动完成后再调用 nix 命令。
USER xbuilder
RUN mkdir code
RUN cd code && \
    wget https://github.com/postgres/postgres/archive/refs/tags/REL_17_6.tar.gz && \
    tar xvf REL_17_6.tar.gz && \
    cd postgres-REL_17_6 && \
    sed -i 's/$(SHELL)/$(shell echo $$SHELL)/g' src/test/regress/GNUmakefile && \
    sed -i '351a system_or_bail("sync");' src/bin/pg_basebackup/t/010_pg_basebackup.pl && \
    sed -i '85a\        system_or_bail("sync");' src/bin/pg_ctl/t/001_start_stop.pl && \
    (sudo -i nix-daemon &) && sleep 5 && \
    for arch in x86_64 aarch64 loongarch64 mips64el; do \
      if [ $arch != loongarch64 ]; then \
        nix develop /home/xbuilder/flakes/#devShells.$arch-linux.postgres -c ./configure --prefix=`pwd`/install --enable-nls --enable-debug --enable-cassert --enable-tap-tests --enable-depend --enable-coverage --enable-profiling --enable-dtrace --enable-injection-points --with-perl --with-python --with-tcl --with-llvm --with-lz4 --with-zstd --with-openssl --with-gssapi --with-ldap --with-pam --with-systemd --with-uuid=ossp --with-libxml --with-libxslt --with-selinux --with-icu; \
      else \
        nix develop /home/xbuilder/flakes/#devShells.$arch-linux.postgres -c ./configure --prefix=`pwd`/install --enable-nls --enable-debug --enable-cassert --enable-tap-tests --enable-depend --enable-coverage --enable-profiling --enable-dtrace --enable-injection-points --with-perl --with-python --with-tcl --with-lz4 --with-zstd --with-openssl --with-gssapi --with-ldap --with-pam --with-systemd --with-uuid=ossp --with-libxml --with-libxslt --with-selinux --with-icu; \
      fi; && \
      nix develop /home/xbuilder/flakes/#devShells.$arch-linux.postgres -c make world -j`nproc` && \
      nix develop ~/flakes/#devShells.$arch-linux.postgres -c make check-world -j`nproc`; \
    done; \
    rm -rf ~/code/*

# 切换回 root 用户
USER root
# 设置容器启动默认 shell 为 bash，并自动启动 nix-daemon 进程。
CMD ["/bin/bash", "-c", "nix-daemon & exec /bin/bash"]
