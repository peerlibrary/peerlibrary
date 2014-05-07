#!/bin/bash -e

# Update all git submodules
git submodule update --init --recursive

# Update all dependencies
mrt install

# Update all NPM packages
EXIT_ON_STARTUP=1 mrt run --once
