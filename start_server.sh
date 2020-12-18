#!/bin/sh
set -ex

MYHOSTNAME=${MYHOSTNAME?Missing env var MYHOSTNAME}
MYNETWORKS=${MYNETWORKS?Missing env var NETWORKS}
USERNAME=${USERNAME?Missing env var USERNAME}
PASSWORD=${PASSWORD?Missing env var PASSWORD}
RELAYHOST=${RELAYHOST?Missing env var RELAYHOST}

# handle sasl
# cat << EOF | saslpasswd2 -pc -u ${MYHOSTNAME} ${USERNAME}
# $PASSWORD
# EOF

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

cat > /etc/postfix/sasl_passwd << EOF
${RELAYHOST} ${USERNAME}:${PASSWORD}
EOF

postmap /etc/postfix/sasl_passwd

rm -r /var/run/saslauthd
ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd

postconf "smtpd_sasl_auth_enable = yes"
postconf "smtpd_sasl_security_options = noanonymous"
postconf "smtpd_sasl_local_domain = ${MYHOSTNAME}"
cp /opt/postfix/master.cf /etc/postfix/master.cf
adduser postfix sasl

# These are required.
postconf "myhostname = ${MYHOSTNAME}"
postconf "mydestination = "

# Override what you want here. The 10. network is for kubernetes
postconf "mynetworks = ${MYNETWORKS}"

# http://www.postfix.org/COMPATIBILITY_README.html#smtputf8_enable
postconf "smtputf8_enable = no"

# This makes sure the message id is set. If this is set to no dkim=fail will happen.
postconf "always_add_missing_headers = yes"

# smtp port restrictions
postconf "smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination"

# submission port restrictions
postconf "mua_client_restrictions = permit_sasl_authenticated, reject"
postconf "mua_sender_restrictions = permit_sasl_authenticated, reject"
postconf "mua_helo_restrictions = permit_mynetworks, reject_non_fqdn_hostname, reject_invalid_hostname, permit"
postconf "mua_relay_restrictions = permit_sasl_authenticated,reject"

# TLS config
postconf "smtpd_use_tls = yes"
postconf "smtpd_tls_auth_only = yes"
postconf "smtpd_tls_mandatory_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "smtpd_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "smtp_tls_protocols = !SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
postconf "tls_high_cipherlist = ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256"
postconf 'smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache'
postconf 'smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache'

# SMTP RELAY
postconf "relayhost = ${RELAYHOST}"
postconf "smtp_sasl_auth_enable = yes"
postconf "smtp_sasl_security_options = noanonymous"
postconf "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf "smtp_use_tls = yes"

if test -n "$SSL_CERT_PATH" -a -n "$SSL_KEY_PATH"; then
    mkdir -p /etc/postfix/ssl
    cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert.pem
    cp "$SSL_KEY_PATH" /etc/postfix/ssl/key.pem
    chmod 600 /etc/postfix/ssl/cert.pem
    chmod 600 /etc/postfix/ssl/key.pem

    # Postfix configuration
    postconf "smtpd_tls_cert_file=/etc/postfix/ssl/cert.pem"
    postconf "smtpd_tls_key_file=/etc/postfix/ssl/key.pem"
fi

/etc/init.d/rsyslog start
/etc/init.d/saslauthd start
/etc/init.d/postfix start

tail -F /var/log/mail.log
