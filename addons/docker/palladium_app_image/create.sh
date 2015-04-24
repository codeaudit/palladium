#!/bin/bash
###############################################
# Script to build an Palladium app docker image
# Assumption: palladium_base image available
###############################################


# $1 = Path to your application, e.g. .../examples/iris/
# $2 = Base image name, e.g. ottogroup/palladium_base:0.9.1
# $3 = Image name, e.g. myname/my_palladium_app:1.0


# Copy files into same directory as Dockerfile 
tar cvzf app.tar.gz --exclude .git --directory=$1 .


# Get folder name and modify path:
# /path/to/folder ->  /path/to/folder/
f=${1##*/}
LEN=$(echo ${#f})
if [ $LEN -lt 1 ]; then
    f=${1%*/}
    f=${f##*/}
    p=$1
else
   p=$1
fi


# Write Dockerfile
FILE="Dockerfile"

/bin/cat <<EOM >$FILE-app
#############################################################
# Dockerfile to build palladium app
# Based on palladium_base image
#############################################################

# Set the base image to $2
FROM $2

# Copy file
# COPY $f /root/palladium/app
ADD app.tar.gz /root/palladium/app

#####################################################
# If you want to add conda channels, please add here
# Example: RUN conda config --add channels <channel>



#####################################################

ENV LANG C.UTF-8 

# Set Workdir
WORKDIR /root/palladium/app
EOM



# Install dependencies if needed. Look for directory "python_packages"
if [ -f $p\requirements.txt ]; then 
    echo "RUN conda install --yes --file requirements.txt" >> $FILE-app
fi

if [ -d $p\python_packages ]; then 
    FILES=$1python_packages/* 
    echo "RUN cd python_packages \ " >> $FILE-app
    for f in $FILES 
    do
       f="${f##*python_packages/}"
       fname="${f%.tar.gz}"
       echo " && tar -xvf $f && rm $f &&  cd $fname && python setup.py install && cd .. && rm -r $fname \  " >> $FILE-app
    done 
    echo " && echo 'Done installing packages' " >> $FILE-app
fi

/bin/cat <<EOM >>$FILE-app
# Set PALLADIUM_CONFIG 
ENV PALLADIUM_CONFIG /root/palladium/app/config.py
EOM

if [ -f $p\setup.py ]; then 
    # Install app
    echo "RUN  python setup.py install" >>$FILE-app
fi

# Build image
sudo docker build -f $FILE-app -t $3 . 

# Remove app folder
rm app.tar.gz



#########################################
# Build gunicorn server image on top 
# of the app image
#########################################


/bin/cat <<EOM >$FILE-gunicorn
############################################################
# Dockerfile to build palladium with gunicorn autostart
# Based on $3
############################################################

FROM $3

# File Author / Maintainer
MAINTAINER Palladium

RUN pld-fit

RUN conda install --yes gunicorn

# For Postgres support
# RUN apt-get update && apt-get install -y libpq-dev

EXPOSE 8000


EOM

echo "CMD gunicorn --workers=3 -b" '$'"(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'):8000  palladium.server:app" >>$FILE-gunicorn

# Build image
sudo docker build -f $FILE-gunicorn -t ${3%%:*}_predict:${3##*:} .

