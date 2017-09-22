#!/bin/bash
#
# NAME: build.sh
# AUTHOR: Sherman Rose <s.rose@vtime.net>
# DESCRIPTION: 
# Will setup a server to act as the vTime Let's Encrypt host  
# For more information consult 'docs/'

## VARIABLES
CERTBOT_VERSION="v0.18.2"
WORK_DIR="/tmp/build"
PRE_REQS="awscli curl python2.7 python-pip"

## HELPER VARIABLES - Only touch if you know what is going on here
CERTBOT_DIR="$WORK_DIR/certbot-$CERTBOT_VERSION"
APT_CACHE="true"
APT_CACHE_URL='"http://172.17.0.1:3142";'

## USEFUL FUNCTIONS

msg(){
  echo "=====> $@"
}

# Check a command exists silently 
check() { command -v "$1" 2>/dev/null ; }
# Easy exit with message
bail() { echo "[ERROR] $1"; exit 1; }

# SCRIPT FUNCTIONS
cleanup() {
 msg "Cleaning Up"
 rm -r "$WORK_DIR"
}

setup() {
  msg "Setup"
  mkdir "$WORK_DIR"
  # Check if we should set up an apt cache before we start
  if [[ "$APT_CACHE" == true ]]; then
   echo "Acquire::HTTP::Proxy $APT_CACHE_URL" >> /etc/apt/apt.conf.d/01proxy 
   echo 'Acquire::HTTPS::Proxy "false";' >> /etc/apt/apt.conf.d/01proxy
  fi
  # Need to ensure we have some prequsq
  msg "Running apt! (this will take some time)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get -qq update && apt-get install -y $PRE_REQS >/dev/null
}

get_certbot() {
  msg "Getting Certbot Release $CERTBOT_VERSION"
  [[ -z "$(check curl)" ]] && bail "Couldn't find curl!" 
  curl --output "$CERTBOT_DIR.tar.gz" \
       --location \
       --silent \
       "https://github.com/certbot/certbot/archive/$CERTBOT_VERSION.tar.gz"
  tar -xzf "$CERTBOT_DIR.tar.gz" -C "$WORK_DIR"
}


## START BUIDLING!

# Check out working dir doesn't exit, remove it if it does and then setup for build
[[ ! -d "$WORK_DIR"  ]] || cleanup 
setup

# Get the specified version of certbot 
get_certbot

# Testing pause in case of insepction needs
while true; do 
  echo -e "blocking in case you need to check things. Type 'finsihed' to continue: \n"
  read  NOW_WHAT
  case $NOW_WHAT in 
    "finished" ) exit 0;;
    * ) echo "Type 'finished' man";;
 esac
done

