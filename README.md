该项目是 xflow 多架构打包环境构建配置文件，可在 x86_64 平台上构建出多平台的打包环境。

使用前先执行如下命令运行 binfmt（执行后在整个系统运行期间都有效，多次执行无影响，但重启系统后需再次执行）：
```console
$ docker run --rm --privileged tonistiigi/binfmt --install all
```

然后依次执行如下命令创建多架构 builder（执行后永久生效）：
```console
$ docker buildx create --name multiarch --driver docker-container --use --driver-opt network=host
$ docker buildx inspect --bootstrap
```

然后执行如下命令创建一个本地 registry 用来存储多架构镜像（执行后永久生效）。
```console
$ docker run -d --restart=always -p 5000:5000 --name registry registry:2
```

最后在当前目录执行如下命令一次构建多平台的镜像：
```console
$ docker buildx build --platform linux/amd64,linux/arm64,linux/loong64 -t localhost:5000/xflow-multiarch --push .
```

构建成功后分别使用如下命令运行对应平台的镜像：
```console
# 运行 x86_64 平台容器。
$ docker run -it --rm --privileged --platform linux/amd64 localhost:5000/xflow-multiarch

# 运行 aarch64 平台容器。
$ docker run -it --rm --privileged --platform linux/arm64 localhost:5000/xflow-multiarch

# 运行 loongarch64 平台容器。
$ docker run -it --rm --privileged --platform linux/loong64 localhost:5000/xflow-multiarch
```
