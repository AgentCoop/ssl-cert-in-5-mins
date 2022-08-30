# Overview
A Bash script to install an SSL certificate for local development in 5 minutes.

### How to use
Issue certificates:
```bash
$ ./issue_cert.sh -d mysite.com -s subdomain 
```

### Adding a root certificate system-wide

#### Archlinux
```bash
$ sudo trust anchor --store rootCA.crt
```
or copy the certificate to the _/etc/ca-certificates/trust-source/anchors_ directory and run update-ca-trust as root.

### Adding a root certificate for the browsers:
##### Chrome
Go to chrome://settings/certificates, Authorities tab and import the certificate. 

### Test configuration for a PHP project

Check out *./nginx* directory to see an example configuration.

### Debug
```bash
openssl s_client -verify 5 -showcerts -connect mysite.com </dev/null
```
