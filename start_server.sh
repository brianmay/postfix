#!/bin/sh
set -ex

MYHOSTNAME=${MYHOSTNAME?Missing env var MYHOSTNAME}
USERNAME=${USERNAME?Missing env var USERNAME}
PASSWORD=${PASSWORD?Missing env var PASSWORD}
SSL_CERT_PATH=${SSL_CERT_PATH?Missing env var SSL_CERT_PATH}
SSL_KEY_PATH=${SSL_KEY_PATH?Missing env var SSL_KEY_PATH}

# handle sasl
cat << EOF | saslpasswd2 -pc -u ${MYHOSTNAME} ${USERNAME}
$PASSWORD
EOF

cat > /etc/default/saslauthd << EOF
START=yes
DESC="SASL Authentication Daemon"
NAME="saslauthd"
MECHANISMS="sasldb"
MECH_OPTIONS=""
THREADS=5
OPTIONS="-c -m /var/spool/postfix/var/run/saslauthd"
EOF

cat > /etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: PLAIN LOGIN
EOF

rm -r /var/run/saslauthd
ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd

postconf "smtp_sasl_auth_enable = yes"
postconf "smtp_sasl_security_options = noanonymous"
postconf "smtpd_sasl_local_domain = ${MYHOSTNAME}"
cp /opt/postfix/master.cf /etc/postfix/master.cf
adduser postfix sasl

# These are required.
postconf "myhostname = ${MYHOSTNAME}"
postconf "mydestination = "

# Override what you want here. The 10. network is for kubernetes
postconf "mynetworks = 10.0.0.0/8,127.0.0.0/8,172.17.0.0/16"

# http://www.postfix.org/COMPATIBILITY_README.html#smtputf8_enable
postconf "smtputf8_enable = no"

# This makes sure the message id is set. If this is set to no dkim=fail will happen.
postconf "always_add_missing_headers = yes"

# TLS config
postconf "smtpd_use_tls = yes"
postconf "smtpd_tls_auth_only = yes"
postconf "smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "smtp_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "tls_high_cipherlist = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256"
postconf 'smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache'
postconf 'smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache'

mkdir -p /etc/postfix/ssl
cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert.pem
cp "$SSL_KEY_PATH" /etc/postfix/ssl/key.pem
chmod 600 /etc/postfix/ssl/cert.pem
chmod 600 /etc/postfix/ssl/key.pem

# Postfix configuration
postconf "smtpd_tls_cert_file=/etc/postfix/ssl/cert.pem"
postconf "smtpd_tls_key_file=/etc/postfix/ssl/key.pem"

/etc/init.d/rsyslog start
/etc/init.d/saslauthd start
/etc/init.d/postfix start

ls -l /var/spool/postfix/var/run/saslauthd
tail -F /var/log/mail.log
