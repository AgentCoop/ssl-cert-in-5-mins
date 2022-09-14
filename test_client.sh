#!/bin/bash

openssl s_server \
  -CAfile ./rootCA.pem \
  -cert server.crt \
  -key server.key \
  --accept 4040 &

sleep 1

openssl s_client \
  -cert $1 \
  -key $2 \
  -connect localhost:4040