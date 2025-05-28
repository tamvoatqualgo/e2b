FROM golang:1.24-alpine3.21 AS builder

RUN apk add --no-cache make

WORKDIR /build/shared

COPY .shared/go.mod .shared/go.sum ./
RUN go mod download

COPY .shared/pkg pkg

WORKDIR /build/proxy

COPY go.mod go.sum Makefile ./
RUN go mod download

COPY main.go main.go
RUN go mod tidy
RUN --mount=type=cache,target=/root/.cache/go-build make build 
RUN chmod +x /build/proxy/bin/client-proxy

FROM alpine:3.21

COPY --from=builder /build/proxy/bin/client-proxy .

ENTRYPOINT [ "./client-proxy"]
