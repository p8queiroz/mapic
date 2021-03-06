#!/bin/bash
function abort() {
	echo $1
	exit 1;
}


# check domain ENV is set
echo "Checking host domain...$SYSTEMAPIC_DOMAIN"
[ -z "$SYSTEMAPIC_DOMAIN" ] && abort "Build failed! Need to set SYSTEMAPIC_DOMAIN ENV variable, eg. export SYSTEMAPIC_DOMAIN=dev.systemapic.com"

# copy config
# echo "Copying config file"
# cp config/$SYSTEMAPIC_DOMAIN.nginx.conf nginx.conf || abort "Build failed! $SYSTEMAPIC_DOMAIN.nginx.conf doesn't exist";

# create crypto
if test -f dhparams.pem; then
  echo 'Using pre-existing Strong Diffie-Hellmann Group'
else
  echo 'Creating Strong Diffie-Hellmann Group'
  openssl dhparam -out dhparams.pem 2048 || exit 1
fi

# build
echo 'Building image'
docker build -t mapic/nginx:latest . || exit 1

# clean up
# rm nginx.conf
