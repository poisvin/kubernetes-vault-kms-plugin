FROM golang as builder
RUN mkdir -p /go/src/github.com/poisvin/kubernetes-vault-kms-plugin
COPY . /go/src/github.com/poisvin/kubernetes-vault-kms-plugin/
COPY ./vault-values.yaml /go/
WORKDIR /go
RUN go build -tags netgo -a -v github.com/poisvin/kubernetes-vault-kms-plugin/vault/server

FROM alpine:latest
COPY --from=builder /go/server /bin/k8s-kms-plugin
COPY --from=builder /go/vault-values.yaml /
CMD ["/bin/k8s-kms-plugin", "-socketFile=/var/run/kmsplugin/socket.sock", "-vaultConfig=/vault-values.yaml", "-tokenFile=/home/vault/.vault-token"]
