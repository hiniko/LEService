#!/bin/bash
#
# NAME: build.sh
# AUTHOR: Sherman Rose <s.rose@vtime.net>
# DESCRIPTION: 
# Will setup a server to act as the vTime Let's Encrypt host  
# For more information consult 'docs/'
#
# WARNING!
# This script requires user interaction! It will print the pubkey you need
# to add to the user which pulls from the git repo! Also you will need a
# for jenkins in order to ssh in during scripted jobs
#


## VARIABLES
CERTBOT_VERSION="0.18.2" #Leave out the v, it will be added later
WORK_DIR="/tmp/build"
DEBUG=true

## HELPER VARIABLES - Only touch if you know what is going on here
CERTBOT_WORK_DIR="$WORK_DIR/certbot-${CERTBOT_VERSION}"
APT_PACKAGES="git python pwgen"
APT_BUILD_PACKAGES="build-essential curl openssh-client python-dev libssl-dev libffi-dev"
APT_CACHE="true"
APT_CACHE_URL='"http://172.17.0.1:3142";'
REPO_URL="github.com"
REPO_SSH_URL='http://192.168.1.177/devops/LetsEncryptService.git'  

if [[ $DEBUG ]]; then
  SILENT=">/dev/null"
else
  SILENT=""
fi

## USEFUL FUNCTIONS

# tagged echo
msg(){ echo "=====> $@"; }
# Check a command exists silently 
check() { command -v "$1" 2>/dev/null ; }
# Easy exit with message [ERROR] tag will make it easier for monitoring
bail() { echo "[ERROR] $1"; exit 1; }

# SCRIPT FUNCTIONS
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
  apt-get -qq update && apt-get install -y $APT_PACKAGES  $APT_BUILD_PACKAGES 
  msg "Download pip from not apt..."
  curl https://bootstrap.pypa.io/get-pip.py | python
  msg "Install Non Debian aws cli"
  pip install awscli
}                                   

get_certbot() {
  msg "Getting Certbot Release $CERTBOT_VERSION"
  [[ -z "$(check curl)" ]] && bail "Couldn't find curl!" 
  curl --output "$CERTBOT_WORK_DIR.tar.gz" \
       --location \
       --silent \
       "https://github.com/certbot/certbot/archive/v$CERTBOT_VERSION.tar.gz"
  tar -xzf "$CERTBOT_WORK_DIR.tar.gz" -C "$WORK_DIR"
}


install_certbot(){
  msg "Installing Certbot" 
  cd "$CERTBOT_WORK_DIR"
  python setup.py install
  msg "Installing AWS Route 53 support"
  cd "$CERTBOT_WORK_DIR/certbot-dns-route53"
  python setup.py install
} 

create_certbot_workspace(){
  # Create the certbot user with a random password, we will be using key pairs anyhow
  useradd --create-home certbot 
  echo "certbot:$(pwgen 20)" | chpasswd
  mkdir /home/certbot/.ssh 
  ssh-keygen -f /home/certbot/.ssh/id_rsa -t rsa -N ''
  git clone "$REPO_SSH_URL" /home/certbot/config
  # Fix ownership
  chown -R certbot:certbot /home/certbot
}

get_repo(){
  msg "Getting LE Config Repo"
  mkdir "$WORK_DIR"
}

cleanup() {
 msg "Cleaning Up"
 rm -r "$WORK_DIR"
 apt-get remove --purge $APT_BUILD_PACKAGES
}

# test certbot installation
#TODO Sanity checks! 

## START BUIDLING!

# Check out working dir doesn't exit, remove it if it does and then setup for build
[[ ! -d "$WORK_DIR"  ]] || cleanup 

# Get all of te pre reqs
setup

# Get the specified version of certbot 
get_certbot

# Installation of certbot and route53 module
install_certbot

# Build certbot user + repo
create_certbot_workspace

# Get configuration repo
#TODO - Need to get git repo up

# Cleanup!!

# Testing pause in case of insepction needs
if [[ $DEBUG ]]; then
  while true; do 
    echo -e "blocking in case you need to check things. Type 'finsihed' to continue: \n"
    read  NOW_WHAT
    case $NOW_WHAT in 
      "finished" ) exit 0;;
      * ) echo "Type 'finished' man";;
   esac
  done
fi
