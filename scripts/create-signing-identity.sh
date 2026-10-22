#!/bin/bash
set -euo pipefail

name="Toolbelt Local Signing"
if security find-identity -p codesigning | grep -q "$name"; then
  echo "identity '$name' already exists"
  exit 0
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cd "$work_dir"

cat > cert.cnf <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $name
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 -config cert.cnf
password="$(openssl rand -hex 12)"
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out identity.p12 -passout "pass:$password" 2>/dev/null \
  || openssl pkcs12 -export -inkey key.pem -in cert.pem -out identity.p12 -passout "pass:$password"
security import identity.p12 -k "$HOME/Library/Keychains/login.keychain-db" -P "$password" -T /usr/bin/codesign
echo "identity '$name' created"
