#!/bin/bash
#
# This script configures a Bitlancer Strings OpenLDAP server already
# puppetized with Bitlancer's puppet-openldap module.
#
# RUN WITH CARE!
#
# Instructions:
#
# * Spin up a CentOS 6.x server with ius, epel, and puppetlabs repos
# * Grab this directory from git and pop in on said server
# * Run this script
# * Review information in output
# * Terminate CentOS 6.x server
# * Profit
#

# Clean up
if [ -f /tmp/strings.ldif ]; then
  rm /tmp/strings.ldif
fi

# Install packages
yum -y -q install openldap-servers apg mlocate
updatedb
echo

# Gather information
read -p "Client Name (ie: Bitlancer LLC): " CLIENT_NAME
read -p "Client Domain (ie: bitlancer-infra.net): " CLIENT_DOMAIN
read -p "Client LDAP Server IP (ie: 166.78.255.233): " CLIENT_LDAP_SERVER_IP
stty -echo
read -p "Client LDAP Server Root Password (ie: bob123): " CLIENT_LDAP_SERVER_ROOT_PASSWORD
stty echo
echo
echo
echo "  Name: $CLIENT_NAME"
echo "  Domain: $CLIENT_DOMAIN"
echo "  IP: $CLIENT_LDAP_SERVER_IP"
echo

# Sleeping
echo ">>> We will run an LDIF that might cause some damage... 5 seconds to CTRL-C!"
sleep 5
echo

# Generate password hash for LDIF
echo ">>> Generating password hash..."
echo
ROOTDN_PASSWORD=`apg -n 1 -m 64 -a 1`
ROOTDN_PASSWORD_HASH=`slappasswd -s "$ROOTDN_PASSWORD"`
echo "  PASSWORD: $ROOTDN_PASSWORD"
echo

# Generate LDIF
echo ">>> Generating LDIF..."
cat strings.ldif.template | while read line; do
  while [[ "$line" =~ (\$\{[a-zA-Z_][a-zA-Z_0-9]*\}) ]]; do
    LHS=${BASH_REMATCH[1]}
    RHS="$(eval echo "\"$LHS\"")"
    line=${line//$LHS/$RHS}
  done
  echo $line >> /tmp/strings.ldif
done

# Exit
echo ">>> Setup is done"
exit 0
