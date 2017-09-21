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

## HELPER VARIABLES - Only touch if you know what is going on here
CERTBOT_DIR="$WORK_DIR/certbot-$CERTBOT_VERSION"

## USEFUL FUNCTIONS

# Check a command exists silently 
check() { command -v "$1" 2>/dev/null ; }
# Easy exit with message
bail() { echo "[ERROR] $1"; exit 1; }

# SCRIPT FUNCTIONS
cleanup() {
 echo "===== Cleaning Up"
 rm -r "$WORK_DIR"
}

setup() {
  echo "===== Setup"
  mkdir "$WORK_DIR"
}

get_certbot() {
  [[ -z "$(check curl)" ]] && bail "Couldn't find curl!" 
  curl --output "$CERTBOT_DIR.tar.gz" \
       --location \
       --silent \
       "https://github.com/certbot/certbot/archive/$CERTBOT_VERSION.tar.gz"
  tar -xzf "$CERTBOT_DIR.tar.gz" -C "$WORK_DIR"
}


## START BUIDLING!

# Check out working dir doesn't exit, remove it if it does and then setup for build
[[ ! -d "$WORK_DIR"  ]] || cleanup && setup

# Get the specified version of certbot 
get_certbot

