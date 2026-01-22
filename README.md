本项目旨在通过 `Docker + Nix + binfmt` 在 `x86_64` 架构上生成各种软件的 `多架构` 编译环境，具体支持的软件请查看 `flake.nix` 中的 `devShells` 属性。

首次使用先执行如下命令：
```console
# 创建 binfmt，用于 x86_64 上运行其他架构的软件。
$ docker run --name binfmt --restart=always --privileged tonistiigi/binfmt --install all

# 创建便于容器间互相使用名称访问的网路。
$ docker network create xbuilder

# 创建 nix 缓存服务（建议定期执行 docker commit nixcache nixcache 保存缓存容器）。
$ docker build -t nixcache -f Dockerfile.nixcache .
$ docker run -d --name nixcache --network xbuilder --restart=always nixcache
```

然后在当前目录执行如下命令构建编译环境（每当编译环境有变更后也只需从这里开始运行）：
```console
$ DOCKER_BUILDKIT=0 docker build --network xbuilder -t xbuilder -f Dockerfile.xbuilder .
```

构建成功后使用如下命令运行编译环境：
```console
$ docker run -it --network xbuilder --rm --privileged xbuilder bash
```

当第一次构建完成编译环境后或者后续有新的构建时，建议执行如下命令上传缓存（密码请查看 Dockerfile.nixcache）：
```console
$ nix copy --all --to ssh://root@nixcache 
```
