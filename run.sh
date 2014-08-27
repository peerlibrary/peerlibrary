#!/bin/bash -e

if [[ -n "$PREFIX" ]]; then
	PREFIX="$PREFIX-"
fi
if [[ -n "$TAG" ]]; then
	TAG=":$TAG"
fi

ARGS=""
if [[ -n "$ROOT_URL" ]]; then
	ARGS="$ARGS -e ROOT_URL=$ROOT_URL"
fi
if [[ -n "$MAIL_URL" ]]; then
	ARGS="$ARGS -e MAIL_URL=$MAIL_URL"
fi
if [[ -n "$METEOR_SETTINGS" ]]; then
	if [[ -e "$METEOR_SETTINGS" ]]; then
		ARGS="$ARGS -e METEOR_SETTINGS='$(cat $METEOR_SETTINGS | sed ':a;N;$!ba;s/\n/ /g' | sed 's/\s//g')'"
	else
		ARGS="$ARGS -e METEOR_SETTINGS='$METEOR_SETTINGS'"
	fi
fi

if [[ -z "$PEERDB_INSTANCES" ]]; then
	PEERDB_INSTANCES="1"
fi
if [[ -z "$WORKER_INSTANCES" ]]; then
	WORKER_INSTANCES="1"
fi

echo "Running with prefix '$PREFIX', tag '$TAG', PeerDB instances $PEERDB_INSTANCES, worker instances $WORKER_INSTANCES."
echo "Arguments:$ARGS"

mkdir -p "/srv/${PREFIX}storage"

for I in $(seq 1 $PEERDB_INSTANCES); do
	mkdir -p "/srv/log/${PREFIX}peerlibrary/peerdb$I"
	docker run -d --name "${PREFIX}peerdb$I" -h "${PREFIX}peerdb$I.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES=0 -e PEERDB_MIGRATIONS_DISABLED=1 -e PEERDB_INSTANCES="$PEERDB_INSTANCES" -e PEERDB_INSTANCE="$((I-1))" $ARGS -v "/srv/log/${PREFIX}peerlibrary/peerdb$I:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" "peerlibrary/peerlibrary$TAG"
done

for I in $(seq 1 $WORKER_INSTANCES); do
	mkdir -p "/srv/log/${PREFIX}peerlibrary/worker$I"
	docker run -d --name "${PREFIX}worker$I" -h "${PREFIX}worker$I.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES="$WORKER_INSTANCES" -e PEERDB_MIGRATIONS_DISABLED=1 -e PEERDB_INSTANCES=0 $ARGS -v "/srv/log/${PREFIX}peerlibrary/worker$I:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" "peerlibrary/peerlibrary$TAG"
done

mkdir -p "/srv/log/${PREFIX}peerlibrary/web1"

docker run -d --name "${PREFIX}web1" -h "${PREFIX}web1.peerlibrary.server1.docker" -e MONGO_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/peerlibrary" -e MONGO_OPLOG_URL="mongodb://${PREFIX}mongodb.mongodb.server1.docker/local" -e WORKER_INSTANCES=0 -e PEERDB_INSTANCES=0 $ARGS -v "/srv/log/${PREFIX}peerlibrary/web1:/var/log/peerlibrary" -v "/srv/${PREFIX}storage:/storage" "peerlibrary/peerlibrary$TAG"
