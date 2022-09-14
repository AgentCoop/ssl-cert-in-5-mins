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

    ${bold}--root-ca${normal}
      Path to a directory with the root certificate.

    ${bold}-t${normal}
      Specifies a certificate type to issue. Allowed values: ( client | server | intermediate ). Defaults to server.
      A root certificate will be generated unless --root-ca is provided.

    ${bold}--skip-hosts${normal}
HELP
}

DOMAIN=
SUBDOMAINS=( )
VALID_DAYS=36500
ROOT_CA_KEY=
ROOT_CA_CERT=
KEY_LEN=2048
SKIP_HOSTS=false
OUT_DIR=
CERT_TYPE=server

# Resolve specified subdomains to localhost
add_to_hosts() {
  echo -e "127.0.0.1\t$DOMAIN" | sudo tee -a /etc/hosts

  for sub in "${SUBDOMAINS[@]}"; do
    echo -e "127.0.0.1\t$sub.$DOMAIN" | sudo tee -a /etc/hosts
  done
}

gen_private_key() {
  ROOT_CA_KEY="$OUT_DIR/rootCA.key"
  openssl genrsa -des3 -out "$ROOT_CA_KEY" $KEY_LEN
}

gen_root_CA() {
  ROOT_CA_CERT="$OUT_DIR/rootCA.pem"
  openssl req \
    -x509 \
    -new \
    -nodes \
    -key "$ROOT_CA_KEY" \
    -sha256 \
    -days $VALID_DAYS \
    -config "$OUT_DIR/openssl.cfg" \
    -extensions root_cert \
    -out "$ROOT_CA_CERT" \
    -subj "/C=GL/ST=None/L=Silicon Pit/O=Byte, Inc./OU=IT/CN=AgentCoop's Certificate Authority"
  # Convert PEM to the crt format
  openssl x509 -outform der -in "$ROOT_CA_CERT" -out "$OUT_DIR/rootCA.crt"
}

gen_dhparam() {
  openssl dhparam -out dhparam.pem $KEY_LEN
}

prepare_cfg() {
  local cfg="$OUT_DIR/openssl.cfg"
  cp ./openssl.cfg $OUT_DIR/
  sed -i "s/:DOMAIN:/$DOMAIN/g" $cfg
  sed -i "s|:DIR:|$OUT_DIR|g" $cfg
}

issue_cert() {
  create_csr
  # Generate certificate sign request
  openssl req \
    -new \
    -sha256 \
    -nodes \
    -out "$OUT_DIR/${CERT_TYPE}.csr" \
    -newkey rsa:$KEY_LEN \
    -keyout "$OUT_DIR/${CERT_TYPE}.key" \
    -config <( cat "$OUT_DIR/csr.cnf" )
  # Sign and issue certificate
  openssl x509 \
    -req \
    -in "$OUT_DIR/${CERT_TYPE}.csr" \
    -CA "$ROOT_CA_CERT" \
    -CAkey "$ROOT_CA_KEY" \
    -CAcreateserial \
    -out "$OUT_DIR/${CERT_TYPE}.crt" \
    -days $VALID_DAYS \
    -sha256 \
    -extfile "$OUT_DIR/openssl.cfg" \
    -extensions "${CERT_TYPE}_cert"

  if [ "$SKIP_HOSTS" != "true" ]; then
    add_to_hosts
  fi
}

clean() {
  rm -f "$OUT_DIR"/{rootCA.srl,csr.cnf,openssl.cfg}
  rm -f "$OUT_DIR/${CERT_TYPE}.csr"
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


#
# Call getopt to validate the provided input.
options=$(getopt -o v:d:s:t:h --long root-ca: --long skip-hosts -- "$@")
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
    --root-ca)
        shift;
        ROOT_CA_CERT=$(realpath "$1")/rootCA.pem
        ROOT_CA_KEY=$(realpath "$1")/rootCA.key
        [[ ! -f "$ROOT_CA_CERT" ]] && {
            echo "Root CA certificate $ROOT_CA_CERT does not exist"
            exit 1
        }
        [[ ! -f "$ROOT_CA_KEY" ]] && {
            echo "Root CA key $ROOT_CA_KEY does not exist"
            exit 1
        }
        ;;
    --skip-hosts)
        SKIP_HOSTS=true
        ;;
    -t)
        shift;
        CERT_TYPE=$1
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

prepare_cfg

if [[ -z "$ROOT_CA_CERT" ]]; then
  bold_ln "Generating root CA certificate and key"
  gen_private_key >/dev/null
  gen_root_CA >/dev/null
fi

issue_cert

clean
