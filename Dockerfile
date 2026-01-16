# 注释 不用做许可证检查
# FROM ghcr.io/openfaas/license-check:0.4.2 AS license-check

FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:1.24 AS build

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

ARG VERSION
ARG GIT_COMMIT

ENV CGO_ENABLED=0
ENV GO111MODULE=on
ENV GOFLAGS=-mod=vendor

# 注释 不用做许可证检查
# COPY --from=license-check /license-check /usr/bin/

# WORKDIR /go/src/github.com/openfaas/faas-netes
# 修改 workdir 
WORKDIR /faas-netes
COPY . .

# 注释 不用做许可证检查
# RUN license-check -path /go/src/github.com/openfaas/faas-netes/ --verbose=false "Alex Ellis" "OpenFaaS Author(s)"
# 注释 跳过测试 加速构建过程
# RUN gofmt -l -d $(find . -type f -name '*.go' -not -path "./vendor/*")

RUN CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} go test -v ./...

RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
        --ldflags "-s -w \
        -X github.com/openfaas/faas-netes/version.GitCommit=${GIT_COMMIT}\
        -X github.com/openfaas/faas-netes/version.Version=${VERSION}" \
        -o faas-netes .

FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:3.22.0 AS ship
# 注释 用于为 Docker 镜像添加元数据标签 不影响镜像使用
# LABEL org.label-schema.license="OpenFaaS CE EULA - non-commercial" \
#       org.label-schema.vcs-url="https://github.com/openfaas/faas-netes" \
#       org.label-schema.vcs-type="Git" \
#       org.label-schema.name="openfaas/faas-netes" \
#       org.label-schema.vendor="openfaas" \
#       org.label-schema.docker.schema-version="1.0"

# 更改 apk 仓库源 将 /etc/apk/repositories 里面 dl-cdn.alpinelinux.org 的 改成 mirrors.aliyun.com
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && apk update

RUN apk --no-cache add \
    ca-certificates

RUN addgroup -S app \
    && adduser -S -g app app

WORKDIR /home/app

EXPOSE 8080

ENV http_proxy=""
ENV https_proxy=""

# COPY --from=build /go/src/github.com/openfaas/faas-netes/faas-netes    .
# 复制构建 stage 的输出位置的二进制文件到当前位置
COPY --from=build /faas-netes    .

RUN chown -R app:app ./

USER app

CMD ["./faas-netes"]
