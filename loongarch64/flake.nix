{
  description = "Building environment for xflow (loongarch64-linux)";

  # 如修改 nixpkgs.url 相关值后请同步更新 Dockerfile 中的 registry 步骤的值。
  inputs = {
    # 2025-08-12: loong-master 分支最新龙芯 commit
    nixpkgs.url = "github:loongson-community/nixpkgs/64275dcdf675155d24d08ba72e1382c1ffe38c2b";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "loongarch64-linux"; };
    in
    {
      devShells.loongarch64-linux.postgres = pkgs.mkShell {
        packages = [
          pkgs.git
          pkgs.autoconf
          pkgs.automake
          pkgs.libtool
          pkgs.pkg-config
          pkgs.readline
          pkgs.zlib
          pkgs.flex
          pkgs.bison
          pkgs.perl
          pkgs.python3
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
          pkgs.systemd
          pkgs.libselinux
          pkgs.lcov
          pkgs.systemtap-sdt
          pkgs.libsystemtap
          pkgs.perlPackages.IPCRun
          pkgs.perlPackages.TestMore
          pkgs.perlPackages.DataDumper
          pkgs.perlPackages.TestSimple
        ];
        shellHook = ''
          export PS1="[xflow-building-env-loongarch64@postgres:\w]\$ "
        '';
      };
    };
}