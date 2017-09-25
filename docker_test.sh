#!/bin/bash

# Small test helper for testing changes made to the setup.sh
# Requires docker
#
# The following will
# * Create a container based on debian:latest
# * Mount the current directory as a folder called /project in 
#   the container
# * Invoke bash with the script as argument, therefore building
#   the server

docker run \
  --name "certbot_test" \
  --interactive \
  --tty=true \
  --mount type=bind,source="$(pwd)",target=/project,ro=true \
  --rm debian:latest \
  /bin/bash -c "/project/build.sh" 

