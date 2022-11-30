echo "Note: Run me as ROOT, please!"
echo " "

printf 'What is the FQDN of the Harbor you are creating certificates for (ex. harbor.example.com)? '
read HARBOR_FQDN


echo "Create Config for CA SSL Certificate."
mkdir -p /tmp/ssl
cd /tmp/ssl
cat <<EOF > ca.cnf
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
encrypt_key = no
distinguished_name = dn
[ dn ]
countryName = US
stateOrProvinceName = California
localityName = Palo Alto
organizationName = VMware
organizationalUnitName = Federal SE
commonName = federal-se.vmware.com
EOF

echo "Create a Self-Signed CA Cert"
openssl genrsa 2048 > ca.key
openssl req -new -x509 -nodes -days 3650 -key ca.key -config ca.cnf > ca.pem

echo "Creating config for new HARBOR SSL cert"
cat <<EOF > harbor.cnf
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
encrypt_key = no
distinguished_name = dn
req_extensions = req_ext
[ dn ]
countryName = US
stateOrProvinceName = California
localityName = Palo Alto
organizationName = VMware
organizationalUnitName = Federal SE
commonName = $HARBOR_FQDN
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = $HARBOR_FQDN
EOF

cat <<EOF > harbor.cnf.ext
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = $HARBOR_FQDN
EOF

# echo "Harbor Cert CNF"
# cat harbor.cnf 

openssl req -newkey rsa:2048 -days 3650 -keyout harbor-key.pem -config harbor.cnf -reqexts req_ext > harbor.csr

# echo "Harbor CSR"
# cat harbor.csr

openssl x509 -req -in harbor.csr -days 3650 -CA ca.pem -CAkey ca.key -set_serial 01 -extensions req_ext -extfile harbor.cnf.ext  > harbor-cert.pem
# Copy the Harbor Certs and Keys to proper Directories
mkdir -p /data/cert
cp harbor-cert.pem /data/cert/
cp harbor-key.pem /data/cert/
cp ca.pem /data/cert/

echo "Adding the new Certificate to the Docker"
mkdir -p /etc/docker/certs.d/$HARBOR_FQDN
cp harbor-cert.pem /etc/docker/certs.d/$HARBOR_FQDN/
cp harbor-key.pem /etc/docker/certs.d/$HARBOR_FQDN/
cp ca.pem /etc/docker/certs.d/$HARBOR_FQDN/

echo "Addind the new CA Certificate to Trusted Root for Unbunu"
cp ca.pem /usr/local/share/ca-certificates/$HARBOR_FQDN.crt
echo "Make sure to run sudo update-ca-certificates if everything looks good" 
echo "command: sudo update-ca-certificates"


echo "Restarting Docker Service"
service docker restart

echo "Cleaning Up"
rm -rf /tmp/ssl

echo " "
echo "##########################################"
echo "Add the following to your harbor.yml file:"
echo "##########################################"
echo " "
echo "https:"
echo "  port: 443"
echo "  certificate: /data/cert/harbor-cert.pem"
echo "  private_key: /data/cert/harbor-key.pem"
