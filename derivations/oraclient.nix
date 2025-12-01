{ stdenv, fetchurl, lib, unzip }:

stdenv.mkDerivation rec {
  pname = "oraclient";
  version = "23.26.0.0.0";
  intver = lib.replaceStrings ["."] [""] version;
  arch = 
    if stdenv.hostPlatform.isx86_64 then 
      "x64" 
    else if stdenv.hostPlatform.isAarch64 then 
      "arm64"
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.system}";

  basicSrc = fetchurl {
    url = "https://download.oracle.com/otn_software/linux/instantclient/${intver}/instantclient-basic-linux.${arch}-${version}.zip";
    sha256 = 
      if stdenv.hostPlatform.isx86_64 then 
        "1x8afqscz6s35j51ksa7v2p31isg1mlmr1brwxir687zy2y9riyn"
      else if stdenv.hostPlatform.isAarch64 then 
        "0cjwa7yc8vnww3cayqw3r88qbshabjnvfd5kdw0qgw4p3q2k56lw"
      else
        throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
  };
  sdkSrc = fetchurl {
    url = "https://download.oracle.com/otn_software/linux/instantclient/${intver}/instantclient-sdk-linux.${arch}-${version}.zip";
    sha256 = 
      if stdenv.hostPlatform.isx86_64 then 
        "1z25165ynmzl5xsdjr7pl73kjvn0x6xixpyjwysbhwwwd83gyr9q"
      else if stdenv.hostPlatform.isAarch64 then 
        "0vn0a6rxq875f0wkb0s9psgf9v0pmqhwlv4rdy5bh7w4y9lzi9mq"
      else
        throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip $basicSrc
    unzip -o $sdkSrc
    runHook postUnpack
  '';

  installPhase = ''
    mkdir -p $out
    cp -r instantclient*/* $out/
  '';

  meta = with lib; {
    description = "Oracle instant client";
    homepage = "http://oracle.com";
    platforms = platforms.unix;
    maintainers = [ ];
  };
}