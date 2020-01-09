#!/bin/bash

set -e

bold=$(tput bold)
normal=$(tput sgr0)

usage() {
  cat <<HELP
${bold}NAME${normal}
       issue_cert.sh - creates a self-signed certificate for local development.

${bold}SYNOPSIS${normal}
      ./issue_cert.sh [options]

${bold}OPTIONS${normal}
     --domain name
            Domain name including any subdomain for which an SSL certificate will be installed.
HELP
}

clean() {
  rm -f \
    server.csr.cnf \
    v3.ext \
    server.csr \
    rootCA.srl \
    rootCA.key
}

# Call getopt to validate the provided input.
options=$(getopt -o h -l domain:,help:: -- "$@")
eval set -- "$options"

while true; do
    case "$1" in
    --domain)
      shift
      DOMAIN="$1"
      ;;
    -h|--help)
        usage
        exit
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done

if [ -z "$DOMAIN" ]; then
  usage;
  exit 1
fi

openssl genrsa -des3 -out rootCA.key 1024

tee server.csr.cnf << CSR
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=GL
L=None
O=LocalDev
OU=LocalDev
emailAddress=dummy@gmail.com
CN=$DOMAIN
CSR

tee v3.ext << V3
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
V3

set -e \
  && openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 999 -out rootCA.pem \
   -subj "/C=GL/ST=None/L=None/O=LocalDev/OU=LocalDev/CN=$DOMAIN" \
  && openssl req -new -sha256 -nodes -out server.csr -newkey rsa:2048 -keyout server.key -config <( cat server.csr.cnf ) \
  && openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 999 -sha256 -extfile v3.ext \
  && openssl dhparam -out dhparam.pem 1024
  && clean
