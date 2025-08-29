{
  description = "Building environment for xflow";

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
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "loongarch64-linux" ] (system:
      let
        pkgs = import ( if system == "loongarch64-linux" then nixpkgs-loong else nixpkgs-nix ) { inherit system; };
      in
      {
        devShells.postgres = pkgs.mkShell {
          name = "postgres-dev";
          buildInputs = [
            pkgs.git
            pkgs.autoconf
            pkgs.automake
            pkgs.libtool
            pkgs.pkg-config
            pkgs.llvm
            pkgs.clang
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
        };
      }
    );
}
