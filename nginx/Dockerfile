ARG NGINX_VERSION=1.26.1

# Stage 1: build mkcert as a static binary
FROM golang:1.22-alpine AS mkcert-builder
ENV CGO_ENABLED=0
RUN go install filippo.io/mkcert@latest

# Stage 2: nginx with mkcert baked in
FROM nginx:${NGINX_VERSION}
COPY --from=mkcert-builder /go/bin/mkcert /usr/local/bin/mkcert
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
