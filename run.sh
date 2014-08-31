#!/bin/bash -e

if [[ -n "$PREFIX" ]]; then
	PREFIX="${PREFIX}_"
fi
if [[ -n "$TAG" ]]; then
	TAG=":$TAG"
fi

if [[ -n "$METEOR_SETTINGS" && -e "$METEOR_SETTINGS" ]]; then
	# sed replaces newlines with spaces
	METEOR_SETTINGS="$(cat $METEOR_SETTINGS | sed ':a;N;$!ba;s/\n/ /g')"
fi

if [[ -z "$PEERDB_INSTANCES" ]]; then
	export PEERDB_INSTANCES="1"
fi
if [[ -z "$WORKER_INSTANCES" ]]; then
	export WORKER_INSTANCES="1"
fi

echo "Running with prefix '$PREFIX', tag '$TAG', PeerDB instances $PEERDB_INSTANCES, worker instances $WORKER_INSTANCES."

mkdir -p "/srv/${PREFIX}storage"

for I in $(seq 1 $PEERDB_INSTANCES); do
	mkdir -p "/srv/log/${PREFIX}peerlibrary/peerdb$I"
	docker run -d --name "${PREFIX}peerdb$I" -h "${PREFIX}peerdb$I.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES=0 -e PEERDB_MIGRATIONS_DISABLED=1 -e PEERDB_INSTANCES -e PEERDB_INSTANCE="$((I-1))" -e ROOT_URL -e MAIL_URL -e METEOR_SETTINGS -v "/srv/log/${PREFIX}peerlibrary/peerdb$I:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" "peerlibrary/peerlibrary$TAG"
done

for I in $(seq 1 $WORKER_INSTANCES); do
	mkdir -p "/srv/log/${PREFIX}peerlibrary/worker$I"
	docker run -d --name "${PREFIX}worker$I" -h "${PREFIX}worker$I.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES -e PEERDB_MIGRATIONS_DISABLED=1 -e PEERDB_INSTANCES=0 -e ROOT_URL -e MAIL_URL -e METEOR_SETTINGS -v "/srv/log/${PREFIX}peerlibrary/worker$I:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" "peerlibrary/peerlibrary$TAG"
done

mkdir -p "/srv/${PREFIX}public"
mkdir -p "/srv/log/${PREFIX}peerlibrary/web1"

# We copy public files out and then map them back in, so that they are available both to nginx and Meteor
docker run --rm=true --entrypoint=/bin/bash "peerlibrary/peerlibrary$TAG" -c 'tar -C /bundle/programs/client/app -c .' | tar -C "/srv/${PREFIX}public" -x

docker run -d --name "${PREFIX}web1" -h "${PREFIX}web1.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES=0 -e PEERDB_INSTANCES=0 -e ROOT_URL -e MAIL_URL -e METEOR_SETTINGS -v "/srv/log/${PREFIX}peerlibrary/web1:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" -v "/srv/${PREFIX}public:/bundle/programs/client/app" "peerlibrary/peerlibrary$TAG"
