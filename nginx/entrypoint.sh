#!/bin/sh
set -e

CERT_DIR=/etc/nginx/certs
DOMAIN="${LOCAL_DOMAIN:-myproject.local}"

# Regenerate if certs are missing or don't cover the configured domain
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/key.pem" ] || \
   ! openssl x509 -in "$CERT_DIR/cert.pem" -text -noout 2>/dev/null | grep -q "$DOMAIN"; then
    echo "Generating certificates with mkcert for localhost and $DOMAIN..."
    mkcert -cert-file "$CERT_DIR/cert.pem" -key-file "$CERT_DIR/key.pem" \
        localhost "$DOMAIN" 127.0.0.1
    cp "$(mkcert -CAROOT)/rootCA.pem" "$CERT_DIR/rootCA.pem"
    echo "Certificates ready. Install nginx/certs/rootCA.pem in your OS once to trust HTTPS."
fi

exec "$@"
