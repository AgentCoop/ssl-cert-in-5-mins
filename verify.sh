#!/bin/bash

openssl verify -verbose -x509_strict -CAfile $1 $2