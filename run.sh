#!/bin/bash -e

mkdir -p /srv/storage
mkdir -p /srv/log/peerlibrary/web1

docker run -d --name web1 -h web1.peerlibrary.server1.docker -e MONGO_URL=mongodb://mongodb.mongodb.server1.docker/peerlibrary -v /srv/log/peerlibrary/web1:/var/log/peerlibrary -v /srv/storage:/storage peerlibrary/peerlibrary
