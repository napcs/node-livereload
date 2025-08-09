# Generate 10 year certs for local testing.
# CA gets set when running the tests with `npm test`.

#!/usr/bin/env bash
set -euo pipefail

mkdir -p ./test/ssl

# 1. Create a test root CA key and certificate
openssl genrsa -out ./test/ssl/test-root.key 2048
openssl req -x509 -new -nodes \
  -key ./test/ssl/test-root.key \
  -sha256 \
  -days 3650 \
  -out ./test/ssl/test-root.pem \
  -subj "/CN=Test Root CA"

# 2. Create a private key for localhost
openssl genrsa -out ./test/ssl/localhost.key 2048

# 3. Create a CSR for localhost with proper SANs
openssl req -new \
  -key ./test/ssl/localhost.key \
  -out ./test/ssl/localhost.csr \
  -subj "/CN=localhost"

cat > ./test/ssl/localhost.ext <<'EOF'
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# 4. Sign the localhost CSR with the test root CA
openssl x509 -req \
  -in ./test/ssl/localhost.csr \
  -CA ./test/ssl/test-root.pem \
  -CAkey ./test/ssl/test-root.key \
  -CAcreateserial \
  -out ./test/ssl/localhost.cert \
  -days 825 \
  -sha256 \
  -extfile ./test/ssl/localhost.ext

# 5. Clean up CSR and ext file
rm ./test/ssl/localhost.csr ./test/ssl/localhost.ext ./test/ssl/test-root.srl

echo "Certificates generated in ./test/ssl/"
echo "CA cert:   ./test/ssl/test-root.pem"
echo "Server key: ./test/ssl/localhost.key"
echo "Server cert: ./test/ssl/localhost.cert"
