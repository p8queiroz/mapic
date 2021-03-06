#!/bin/bash

print_log () {
    echo ""
    echo "$1"
    echo ":::::::::::::::::::::::::::::::::"
    echo ""
}

abort () {
    exit $1
}

# get working dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# get flags
FLAG=$1

clear
        
echo "             ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,                                             "     
echo "          ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                                           "     
echo "         ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;       :;;;;;                             "     
echo "         ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                                          "     
echo "         ,;;;;;;;i;,   :iii;,      ,;ii;;ii:       :iii;;;;;;;;;;;,          ,;ii;;;;;;;;;i,   :iii;,       ,;ii;;;;;;;;                              ,::;:::,,   "     
echo "         ,;;;;;;;i;                                    :i;;;;;;i:     ,,,,        ,i;;;;;;;                      :i;;;;;     :;:;;;;;,          ;;;;;;;:,  ,,:;;  "     
echo "         ,;;;;;;;i;       i;;;;;;i,      ;i;;;;;;i      :i;;;;;;;;;;;;;;;ii;i;     ,i;;;;;;      ,i;;;;;;;;i,      ii;;;        ,;;;;,       ,;;;;;               "     
echo "         ,;;;;;;;i;     ,;;;;;;;;i;     ,i;;;;;;;i:     ,i;;;;;;i;,                ,;;;;;;;     ,i;;;;;;;;;;i,     ,;;;;        ,;;;;,       ;;;;;                "     
echo "         ,;;;;;;;i;     ,;;;;;;;;i;     ,i;;;;;;;i:     ,i;;;i:      :iii;;;ii     ,;;;;;;;      i;;;;;;;;;;i      :i;;;        ,;;;;,       ;;;;;                "     
echo "         ,;;;;;;;i;     ,;;;;;;;;i;     ,i;;;;;;;i:     ,i;;i;      i;;;;;;;;;     ,;;;;;;;      i;;;;;;;;ii      ,i;;;;        ,;;;;,       :;;;;;               "     
echo "         ,;;;;;;;i;     ,;;;;;;;;i;     ,i;;;;;;;i:     ,i;;;i;        ,,,,        ,;;;;;;;         ,,          :i;;;;;;        ,;;;;,         ,;;;;;;;:,   ,,;;, "     
echo "         ,;;;;;;;i;,    :i;;;;;;;i;,    ;i;;;;;;;i;     ;i;;;;;;ii;:,          ,::;;;;;;;;;              ,:;ii;;;;;;;;;;         ,,,,                 ,::;;:::,   "     
echo "         ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      i;;;;;;;;;;;;;;;;;;;;;;                                          "     
echo "         ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      i;;;;;;;;;;;;;;;;;;;;;;                                          "     
echo "          ,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;i;      i;;;;;;;;;;;;;;;;;;;;;                                           "     
echo "             ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;:                                             "     
echo "                   ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,                                                    "     
                                                                                                                                                                       

print_log "Installing to localhost..."
print_log "# Current working directory: $DIR"
print_log "# Downloading code..."


# set env
export MAPIC_DOMAIN=localhost

# init mapic/mapic submodule
cd $DIR
git submodule init
git submodule update --recursive --remote
git submodule foreach --recursive git checkout master

# init mapic/mile submodule
cd $DIR/modules/mile
git submodule init
git submodule update --recursive --remote

# init mapic/engine submodule
cd $DIR/modules/engine
git submodule init
git submodule update --recursive --remote

# init mapic/mapic.js submodule
cd $DIR/modules/mapic.js
git submodule init
git submodule update --recursive --remote

# init mapic/sdk submodule
cd $DIR/modules/sdk
git submodule init
git submodule update --recursive --remote

# install modules in mapic/mapic (for scripts, etc)
cd $DIR
npm install

# create self-signed SSL certs
print_log "# Creating SSL certficate..."
docker run --rm -it --name openssl \
    -v $DIR/config/localhost:/certs \
    wallies/openssl \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /certs/ssl_certificate.key -out /certs/ssl_certificate.pem -subj "/C=NO/ST=Oslo/L=Oslo/O=Mapic/OU=IT Department/CN=localhost"

# update config
print_log "# Updating configuration..."
cd $DIR/scripts
node update-configs.js

# create storage containers
print_log "# Creating storage containers..."
cd $DIR/docker/compose/
./create-storage-containers.sh

# init mongo
print_log "# Initializing Mongo database"
docker run -v $DIR/config/${MAPIC_DOMAIN}:/mapic/config --volumes-from mapic_mongo_store_localhost -it mapic/mongo:latest /init.sh

# install node modules
print_log "# Installing Node modules..."
cd $DIR
print_log "...for Mapic Tile Server"
docker run -v $DIR/config/${MAPIC_DOMAIN}:/mapic/config -v $DIR/modules:/mapic/modules -w /mapic/modules/mile -it mapic/mile:latest npm install --loglevel silent
print_log "...for Mapic Engine"
docker run -v $DIR/config/${MAPIC_DOMAIN}:/mapic/config -v $DIR/modules:/mapic/modules -w /mapic/modules/engine -it mapic/engine:latest npm install --loglevel silent
print_log "...for Mapic.js"
docker run -v $DIR/config/${MAPIC_DOMAIN}:/mapic/config -v $DIR/modules:/mapic/modules -w /mapic/modules/mapic.js -it mapic/engine:latest npm install --loglevel silent


# start server
print_log "# Starting Mapic server..."
cd $DIR/docker/compose/
./start-containers.sh --no-logs


# run travis tests separately
if [[ $FLAG = "travis" ]]; then
    exit
fi

# run tests
print_log "# Running tests..."
sleep 30
cd $DIR/scripts
./run-localhost-tests.sh || abort

# show logs
print_log "# Opening logs..."
cd $DIR/docker/compose/
./show-logs.sh
