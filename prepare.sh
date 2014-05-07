#!/bin/bash -e

# Update all git submodules
git submodule update --init --recursive

# Update all dependencies
mrt install
