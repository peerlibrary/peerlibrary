#!/bin/bash -e

# Change directory to the directory in which the script is in
cd "$(dirname -- "$0")"

# Update all git submodules
git submodule update --init --recursive

# Update all dependencies
mrt install

# Update all NPM packages
PEERDB_INSTANCES=0 PEERDB_SKIP_MIGRATIONS=1 EXIT_ON_STARTUP=1 mrt run --once
