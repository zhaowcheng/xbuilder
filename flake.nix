{
  description = "Multi-architecture build environment for any software.";

  # 如修改 nixpkgs-*.url 相关值后请同步更新 Dockerfile 中的 registry 步骤的值。
  inputs = {
    # 2025-05-24: tag 25.05
    nixpkgs-nix.url = "github:NixOS/nixpkgs/11cb3517b3af6af300dd6c055aeda73c9bf52c48";
    # 2025-08-12: loong-master 分支最新 commit
    nixpkgs-loong.url = "github:loongson-community/nixpkgs/64275dcdf675155d24d08ba72e1382c1ffe38c2b";
    # 2024-11-14: main 分支最新 commit
    flake-utils.url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b";
  };

  outputs = { self, nixpkgs-nix, nixpkgs-loong, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "loongarch64-linux" "mips64el-linux" ] (system:
      let
        mips64elLinuxOverlay = import ./overlays/mips64el-linux.nix;
        pkgs = import ( if system == "loongarch64-linux" then nixpkgs-loong else nixpkgs-nix ) { 
          # mips64el-linux 上编译 xgcc 时会错误的使用 32 位的头文件，为了避免这类问题，明确为该平台指定 abi 为 64 位。
          system = if system == "mips64el-linux" then "mips64el-linux-gnuabi64" else system;
          overlays = if system == "mips64el-linux" then [ mips64elLinuxOverlay ] else [ ];
          config = {
            allowUnsupportedSystem = true;
          };
        };
        scws = pkgs.callPackage ./derivations/scws.nix { };
        oraclient = pkgs.callPackage ./derivations/oraclient.nix { };
      in
      {
        devShells.postgres = pkgs.mkShell {
          name = "postgres";
          buildInputs = [
            # general
            pkgs.git
            pkgs.autoconf
            pkgs.automake
            pkgs.libtool
            pkgs.pkg-config
            # postgres
            pkgs.readline
            pkgs.zlib
            pkgs.flex
            pkgs.bison
            pkgs.python3
            pkgs.perl
            pkgs.tcl
            pkgs.openssl
            pkgs.krb5
            pkgs.openldap
            pkgs.pam
            pkgs.lz4
            pkgs.zstd
            pkgs.gettext
            pkgs.libossp_uuid
            pkgs.libxslt
            pkgs.libxml2
            pkgs.docbook-xsl-nons
            pkgs.docbook_xml_dtd_45
            pkgs.icu
            pkgs.libselinux
            pkgs.lcov
            pkgs.systemtap-sdt
            pkgs.libsystemtap
            pkgs.perlPackages.IPCRun
            pkgs.perlPackages.TestMore
            pkgs.perlPackages.DataDumper
            pkgs.perlPackages.TestSimple
            # postgis
            pkgs.proj
            pkgs.geos
            pkgs.json_c
            pkgs.sfcgal
            pkgs.pcre2
            pkgs.protobufc
            pkgs.cunit
            pkgs.docbook5
            # pgroonga
            pkgs.groonga
            pkgs.msgpack
            # mysql_fdw
            pkgs.libmysqlclient
            # zhparser
            scws
            # oracle_fdw
            oraclient
            pkgs.libaio
            # pgcenter
            pkgs.go
            # patroni
            pkgs.python3
            # pgpool
            pkgs.flex
            pkgs.bison
            pkgs.openssl
            pkgs.openldap
            pkgs.pam
          ] ++ pkgs.lib.optionals (system != "loongarch64-linux" && system != "mips64el-linux") [
            # pg 不支持 loongarch64 的 llvm；mips64el 上 llvm 和 clang 没有编译成功。
            pkgs.llvm
            pkgs.clang
            # postgis 可选库 gdal, dblatex 不支持 loongarch64 和 mips64el。
            pkgs.gdal
            pkgs.dblatex
            # java tools
            pkgs.openjdk
          ] ++ pkgs.lib.optionals (system != "mips64el-linux") [
            # mips64el 上 systemd 没有编译成功。
            pkgs.systemd
            # gtk2 依赖 systemd，所以在 mips64el 上不可用。
            pkgs.gtk2
            # imagemagick 依赖链中的 rustc 不支持 mips64el（error: missing bootstrap url for platform mips64el-unknown-linux-gnuabi64）
            pkgs.imagemagick
          ];

          shellHook = ''
            export SCWS_HOME=${scws}
            export ORACLE_HOME=${oraclient}
            export LD_LIBRARY_PATH=${pkgs.libmysqlclient}/lib:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=${scws}/lib:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=${oraclient}:$LD_LIBRARY_PATH
            export LD_LIBRARY_PATH=${pkgs.libaio}/lib:$LD_LIBRARY_PATH
            export GOPROXY=https://mirrors.aliyun.com/goproxy/
          '';
        };
      }
    );
}