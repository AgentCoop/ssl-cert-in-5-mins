#!/bin/bash

set -e

bold=$(tput bold)
normal=$(tput sgr0)

bold_ln() {
  echo "${bold}${1}${normal}"
}

usage() {
  cat <<HELP
${bold}NAME${normal}
    issue_cert.sh - creates a certificate for local development.

${bold}SYNOPSIS${normal}
    ./issue_cert.sh [options]

${bold}OPTIONS${normal}
    ${bold}-d${normal} domain_name
      A domain name for which an SSL certificate will be issued. A wildcard domain name ${bold}*.domain_name${normal} wil be added to the list
      of the alternative names.

    ${bold}-s${normal} subdomain
      Adds a subdomain. All subdomains and the domain will be resolved to localhost unless ${bold}--skip-hosts${normal} was specified.

    ${bold}-v${normal} days
      Specifies how many days the issued certificate will be valid. Defaults to 36500 days.

    ${bold}--ca-cert${normal}
      Path to a CA certificate file.

    ${bold}--ca-key${normal}
      Path to a CA key file.

    ${bold}--skip-hosts${normal}
HELP
}

DOMAIN=
SUBDOMAINS=( )
VALID_DAYS=36500
CA_KEY=
CA_CERT=
KEY_LEN=2048
SKIP_HOSTS=false
OUT_DIR=

# Resolve specified subdomains to localhost
add_to_hosts() {
  echo -e "127.0.0.1\t$DOMAIN" | sudo tee -a /etc/hosts

  for sub in "${SUBDOMAINS[@]}"; do
    echo -e "127.0.0.1\t$sub.$DOMAIN" | sudo tee -a /etc/hosts
  done
}

gen_private_key() {
  CA_KEY="$OUT_DIR/rootCA.key"
  openssl genrsa -des3 -out "$CA_KEY" $KEY_LEN >/dev/null
}

gen_root_CA() {
  CA_CERT="$OUT_DIR/rootCA.pem"
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days $VALID_DAYS -out "$CA_CERT" \
    -subj "/C=GL/ST=None/L=Lehi/O=Byte, Inc./OU=IT/CN=$DOMAIN"
  openssl x509 -outform der -in "$CA_CERT" -out "$OUT_DIR/rootCA.crt"
}

gen_dhparam() {
  openssl dhparam -out dhparam.pem 2048
}

issue_cert() {
  create_csr && \
  create_v3_ext && \
  openssl req -new -sha256 -nodes -out "$OUT_DIR/$DOMAIN.csr" -newkey rsa:2048 -keyout "$OUT_DIR/cert-$DOMAIN.key" -config <( cat "$OUT_DIR/csr.cnf" ) && \
  openssl x509 -req -in "$OUT_DIR/$DOMAIN.csr" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$OUT_DIR/cert-$DOMAIN.crt" -days $VALID_DAYS -sha256 -extfile "$OUT_DIR/v3.ext"
  rm -f  "$OUT_DIR/$DOMAIN.csr"
  if [ "$SKIP_HOSTS" != "true" ]; then
    add_to_hosts
  fi
}

create_csr() {
  cat > "$OUT_DIR/csr.cnf" << CSR
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=GL
L=Office
O=Bugs' Kingdom, Inc.
OU=IT
emailAddress=buggy@gmail.com
CN=$DOMAIN
CSR
}

# Basic Constraints
# This is a multi-valued extension which indicates whether a certificate is a CA certificate. The first value is CA followed
# by TRUE or FALSE. If CA is TRUE then an optional pathlen name followed by a nonnegative value can be included.
# For example:
# basicConstraints = CA:TRUE
# basicConstraints = CA:FALSE
# basicConstraints = critical, CA:TRUE, pathlen:1
# A CA certificate must include the basicConstraints name with the CA parameter set to TRUE. An end-user certificate must
# either have CA:FALSE or omit the extension entirely. The pathlen parameter specifies the maximum number of CAs that can
# appear below this one in a chain. A pathlen of zero means the CA cannot sign any sub-CA's, and can only sign end-entity
# certificates.


# Extended Key Usage
# This extension consists of a list of values indicating purposes for which the certificate public key can be used. Each
# value can be either a short text name or an OID. The following text names, and their intended meaning, are known:
# Value                  Meaning according to RFC 5280 etc.
# -----                  ----------------------------------
# serverAuth             SSL/TLS WWW Server Authentication
# clientAuth             SSL/TLS WWW Client Authentication
# codeSigning            Code Signing
# emailProtection        E-mail Protection (S/MIME)
# timeStamping           Trusted Timestamping
# OCSPSigning            OCSP Signing
# ipsecIKE               ipsec Internet Key Exchange
# msCodeInd              Microsoft Individual Code Signing (authenticode)
# msCodeCom              Microsoft Commercial Code Signing (authenticode)
# msCTLSign              Microsoft Trust List Signing
# msEFS                  Microsoft Encrypted File System
create_v3_ext() {
  cat > "$OUT_DIR/v3.ext" << V3
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = critical, serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
V3
}

#
# Call getopt to validate the provided input.
options=$(getopt -o v:d:s:h --long ca-key: --long ca-cert: --long skip-hosts -- "$@")
[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}
eval set -- "$options"
while true; do
    case "$1" in
    -h)
      shift
      usage >&2
      exit 1
      ;;
    -v)
        shift
        VALID_DAYS=$1
        ;;
    -s)
        shift
        SUBDOMAINS+=( "$1" )
        ;;
    -d)
        shift;
        DOMAIN=$1
        ;;
    --ca-key)
        shift;
        CA_KEY=$1
        [[ ! -f "$CA_KEY" ]] && {
            echo "CA certificate $CA_KEY does not exists"
            exit 1
        }
        ;;
    --ca-cert)
        shift;
        CA_CERT=$1
        [[ ! -f "$CA_CERT" ]] && {
            echo "CA cetificate $CA_CERT does not exists"
            exit 1
        }
        ;;
    --skip-hosts)
        SKIP_HOSTS=true
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

# Create an output directory.
OUT_DIR="./${DOMAIN}_cert-$(date +%Y-%d_%B_%H_%M)"
mkdir -p $OUT_DIR

if [[ -z "$CA_CERT" ]]; then
  bold_ln "Generating CA key and certificate for ${DOMAIN}"
  gen_private_key >/dev/null
  gen_root_CA >/dev/null
else
  [[ ! -f "$CA_CERT" ]] && {
    echo "Private key file $CA_CERT does not exist"
    rm -rf $OUT_DIR
    exit 1
  }
  [[ ! -f "$CA_KEY" ]] && {
    echo "CA certificate file $CA_KEY does not exist"
    rm -rf $OUT_DIR
    exit 1
  }
fi

issue_cert >/dev/null
