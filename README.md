本项目旨在通过 `Docker + Nix + binfmt` 在 `x86_64` 架构上生成各种软件的 `多架构` 编译环境，具体支持的软件请查看 `flake.nix` 中的 `devShells` 属性。

第一次使用前先执行如下命令安装 binfmt：
```console
$ docker run --name binfmt --restart=always --privileged tonistiigi/binfmt --install all
```

然后在当前目录执行如下命令构建编译环境：
```console
$ docker build -t xbuilder .
```

构建成功后使用如下命令运行编译环境：
```console
$ docker run -it --rm --privileged xbuilder
```
