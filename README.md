# Overview
A Bash script to install an SSL certificate for local development in 5 minutes.

## How to use
Issue certificates:
```bash
$ ./issue_cert.sh --domain yourdomain
$ echo "127.0.0.1  yourdomain" | sudo tee -a /etc/hosts
```

1. Add the root certificate *rootCA.pem* to the list of trusted ones. For Chrome, go to chrome://settings/certificates, Authorities tab.
2. Copy *server.crt*, *server.key* and *dhparam.pem* to a target directory.
3. Have fun!

## Test configuration for a PHP project

Check out *./nginx* directory to see an example configuration.