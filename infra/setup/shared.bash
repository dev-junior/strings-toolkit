#!/bin/bash
#
# Shared variables/functions/executions for any strings infrastructure script
#

# Import configuration
if [ ! -f configuration.bash ]; then
  echo ">>> You must setup configuration.bash!"
  exit 1
else
  source configuration.bash
  echo ">>> Using the following configuration: "
  echo
  echo "    Top Level Domain: $top_level_domain"
  echo "    Data Center: $data_center"
  echo
  echo "    Base Image: $base_image"
  echo "    Base Image Version: $base_image_version"
  echo "    Template Image: $template_image"
  echo
  echo "    OpenStack Username: $os_username"
  echo "    OpenStack API Key: ********************************"
  echo "    OpenStack Region: $os_region"
  echo
  echo "    Puppet Top Level Domain: $puppet_tld"
  echo
  echo "    Kill top level DNS zone on teardown?: $dns_kill_top_zone"
  echo "    DNS Email Address: $dns_email_address"
  echo
fi

# Functions
#
# getServerName: generate a server name
# input: none
# output: servername
#
function getServerName {
  cat /usr/share/dict/words | grep -i "^[a-z]*$" | shuf -n 1 | tr [A-Z] [a-z]
}

#
# getOutputDirectory: generate an output directory
# input: none
# output: directory name
#
function getOutputDirectory {
  directory_name="/tmp/strings.$RANDOM"
  mkdir "$directory_name"
  echo "$directory_name"
}

#
# novaValueByKey: gets a value from a key via file or STDIN
# input: key, [filename]
# output: value
#
function novaValueByKey {
  if [ "$2" ]; then
    grep "^|\ $1" $2 | sed 's/\ //g' | awk -F'|' '{ print $3 }'
  else
    grep "^|\ $1" | sed 's/\ //g' | awk -F'|' '{ print $3 }'
  fi
}

#
# dnsIdByName: gets a DNS record ID by Name
# input: name
# output: value
#
function dnsIdByName {
  grep "|\ $1" | sed 's/\ //g' | awk -F'|' '{ print $2 }'
}

#
# installDependencies: installs dependencies
# input: none
# output: none
#
function installDependencies {
  yum -y -q install apg mlocate python-setuptools sshpass words python-prettytable python-httplib2 > /dev/null
  if [ ! -f /usr/bin/nova ]; then
    easy_install pip > /dev/null
    pip install rackspace-novaclient > /dev/null
  fi
  if [ ! -f /usr/bin/rackdns ]; then
    git clone https://github.com/kwminnick/rackspace-dns-cli > /dev/null
    cd rackspace-dns-cli
    python setup.py install > /dev/null
    cd ..
    rm -rf rackspace-dns-cli
  fi
}

#
# novaExecute: executes something with novaclient
# input: none
# output: none
#
function novaExecute {
  nova --os-tenant-name $os_username --os-auth-url https://identity.api.rackspacecloud.com/v2.0/ --os-auth-system rackspace --os-region-name $os_region --os-username $os_username --os-password $os_api_key --no-cache "$@"
}

#
# dnsExecute: executes something with rackspace DNS
# input: none
# output: none
#
function dnsExecute {
  export NOVA_RAX_AUTH=1
  rackdns --os-tenant-name $os_username --os-auth-url https://identity.api.rackspacecloud.com/v2.0/ --os-username $os_username --os-password $os_api_key --no-cache "$@"
}

#
# waitOnServices: waits on services and only returns when done or timed out
# input: none
# output: none
#
function waitOnServices {
  sleep 300
  waiting=2
  fail_count=0
  while [ "$waiting" -ne 0 ]; do
    waiting=2
    fail_count=$(expr $fail_count + 1)
    for server in "$output_directory"/*.txt; do
      id=$(novaValueByKey id "$server")
      name=$(novaValueByKey name "$server")
      novaExecute show "$id" | grep ACTIVE > /dev/null
      if [ "$?" -gt 0 ]; then
        echo ">>> Still waiting on $name... :("
        sleep 60
        waiting=1
      fi
    done
    if [ "$waiting" -eq 2 ]; then
      waiting=0
    else
      if [ "$fail_count" -gt 10 ]; then
        finishRunning
        echo ">>> Failing fast on this one, something is up..."
        echo ">>> You may want to tear down: $output_directory"
        exit 2
      fi
    fi
  done
}

#
# checkRunning: sees if a strings script is running
# input: none
# output: none
#
function checkRunning {
  if [ -f /tmp/strings.lock ]; then
    read -p "*** We're already running.  Override? (Y/n): " override
    if [ "$override" != "Y" ]; then
      exit 1
    fi
  else
    touch /tmp/strings.lock
  fi
}

#
# finishRunning: cleans up after a run
# input: none
# output: none
#
function finishRunning {
  rm /tmp/strings.lock
}

# Check	if we're already running
checkRunning

# Install packages
installDependencies

# Generate output directory
output_directory=$(getOutputDirectory)