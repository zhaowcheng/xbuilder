该项目是 xflow 多架构打包环境构建配置文件，可在 x86_64 平台上构建出多平台的打包环境。

使用前先执行如下命令运行 binfmt（执行后在整个系统运行期间都有效，重启系统后需再次执行）：
```console
$ docker run --rm --privileged tonistiigi/binfmt --install all
```

分别使用如下命令构建对应平台的镜像：
```console
# 构建 x86_64 平台镜像。
$ docker build --platform linux/amd64 -t xflow-x86_64 x86_64/

# 构建 aarch64 平台镜像。
$ docker build --platform linux/arm64 -t xflow-aarch64 aarch64/

# 构建 loongarch64 平台镜像。
$ docker build --platform linux/loong64 -t xflow-loongarch64 loongarch64/
```

构建成功后分别使用如下命令运行对应平台的镜像：
```console
# 运行 x86_64 平台镜像。
$ docker run -it --rm --privileged --platform linux/amd64 xflow-x86_64

# 运行 aarch64 平台镜像。
$ docker run -it --rm --privileged --platform linux/arm64 xflow-aarch64

# 运行 loongarch64 平台镜像。
$ docker run -it --rm --privileged --platform linux/loong64 xflow-loongarch64
```