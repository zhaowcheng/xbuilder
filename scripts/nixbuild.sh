#!/bin/bash -e
# nix 编译环境配置和验证。

PROGNAME=$(basename $0)
if [[ $# != 2 ]]; then
    echo "Usage: $PROGNAME ARCH NAME" >&2
    exit 1
fi

# postgres 不支持 root 用户运行，所以要用普通用户调用本脚本。
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: This script should not be run as root. Use a normal user." >&2
    exit 1
fi

ARCH=$1
NAME=$2
BUILDROOT=/tmp/$ARCH
mkdir -p $BUILDROOT

# 普通用户使用 nix 需要先启动 nix-daemon 进程，增加 sleep 是为了等到该进程启动完成后再调用 nix 命令。
(sudo -i nix-daemon &) && sleep 5
nix build ~/flakes/#devShells.$ARCH-linux.$NAME

if [ $NAME == postgres ]; then
  #========= postgres ===========
  PGHOME=$BUILDROOT/pgsql
  PGDATA=$PGHOME/data
  PGDATABASE=postgres

  # 下载并解压 postgres 源码。
  cd $BUILDROOT
  wget https://ghfast.top/https://github.com/postgres/postgres/archive/refs/tags/REL_17_6.tar.gz
  tar xvf REL_17_6.tar.gz
  cd postgres-REL_17_6

  # 通常 make 内建变量 SHELL 的值为 `/bin/sh`，而 nix 中的 make 为 `sh`，这会导致 pg_regress 程序失败，所以修改 src/test/regress/GNUmakefile 直接取当前环境变量 SHELL。
  sed -i 's/$(SHELL)/$(shell echo $$SHELL)/g' src/test/regress/GNUmakefile

  # configure
  conflags="--prefix=$PGHOME \
    --enable-nls \
    --enable-debug \
    --enable-cassert \
    --enable-tap-tests \
    --enable-depend \
    --enable-coverage \
    --enable-dtrace \
    --enable-injection-points \
    --with-perl \
    --with-python \
    --with-tcl \
    --with-lz4 \
    --with-zstd \
    --with-openssl \
    --with-gssapi \
    --with-ldap \
    --with-pam \
    --with-uuid=ossp \
    --with-libxml \
    --with-libxslt \
    --with-selinux \
    --with-icu"
  if [ $ARCH == x86_64 || $ARCH == aarch64 ]; then
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags \
      --with-llvm \
      --with-systemd
  elif [ $ARCH == loongarch64 ]; then
    # pg 不支持 loongarch64 的 llvm。
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags \
      --with-systemd
  elif [ $ARCH == mips64el ]; then
    # mips64el 上 llvm、clang、systemd 没有编译成功。
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags
  fi
  
  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make -j$(nproc)
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make check-world

  # 为后续扩展编译配置环境变量。
  export PATH=$PGHOME/bin:$PATH
  export LD_LIBRARY_PATH=$PGHOME/lib:$LD_LIBRARY_PATH
  export PGDATABASE=$PGDATABASE
    
  #========= postgis ===========
  cd $BUILDROOT
  wget https://postgis.net/stuff/postgis-3.6.2dev.tar.gz
  tar xvf postgis-3.6.2dev.tar.gz
  cd postgis-3.6.2dev

  # configure
  conflags="--prefix=$PGHOME --with-sfcgal"
  if [ $ARCH == x86_64 || $ARCH == aarch64 ]; then
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags \
      --with-gui
  elif [ $ARCH == loongarch64 ]; then
    # gdal 不支持 loongarch64 ，所以添加 --without-raster 参数。
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags \
      --with-gui \
      --without-raster
  elif [ $ARCH == mips64el ]; then
    # gdal 不支持 loongarch64 ，所以添加 --without-raster 参数。
    # gtk2 依赖 systemd，而 mips64el 上的 systemd 没编译成功，所以不带 --with-gui 参数。
    nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c ./configure \
      $conflags \
      --without-raster
  fi
  
  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make -j$(nproc)
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install -j$(nproc)
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make check -j$(nproc)
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data

  #========= pgvector ===========
  cd $BUILDROOT
  wget https://ghfast.top/https://github.com/pgvector/pgvector/archive/refs/tags/v0.8.1.tar.gz
  tar xvf v0.8.1.tar.gz
  cd pgvector-0.8.1

  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c psql -d postgres -c "CREATE EXTENSION vector;"
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data

  #========= pgroonga ===========
  cd $BUILDROOT
  wget https://packages.groonga.org/source/pgroonga/pgroonga-4.0.4.tar.gz
  tar xvf pgroonga-4.0.4.tar.gz
  cd pgroonga-4.0.4

  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make HAVE_MSGPACK=1
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c psql -d postgres -c "CREATE EXTENSION pgroonga;"
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data

  #========= mysql_fdw ===========
  cd $BUILDROOT
  wget https://ghfast.top/https://github.com/EnterpriseDB/mysql_fdw/archive/refs/tags/REL-2_9_3.tar.gz
  tar xvf REL-2_9_3.tar.gz
  cd mysql_fdw-REL-2_9_3

  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make USE_PGXS=1
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make USE_PGXS=1 install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c psql -d postgres -c "CREATE EXTENSION mysql_fdw;"
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data

  #========= zhparser ===========
  cd $BUILDROOT
  wget https://ghfast.top/https://github.com/amutu/zhparser/archive/refs/tags/v2.3.tar.gz
  tar xvf v2.3.tar.gz
  cd zhparser

  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c psql -d postgres -c "CREATE EXTENSION zhparser;"
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data

  #========= oracle_fdw ===========
  cd $BUILDROOT
  wget https://ghfast.top/https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_8_0.tar.gz
  tar xvf ORACLE_FDW_2_8_0.tar.gz
  cd oracle_fdw-ORACLE_FDW_2_8_0

  # 编译、安装、测试。
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c make install
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c initdb -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl start -D ./data
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c psql -d postgres -c "CREATE EXTENSION oracle_fdw;"
  nix develop ~/flakes/#devShells.$ARCH-linux.$NAME -c pg_ctl stop -D ./data
    
# 清理
rm -rf $BUILDROOT