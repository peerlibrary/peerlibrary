#!/bin/bash

EXIT_CODE=0

# We run tests for each package separately, otherwise they can interfere with each other
while read package; do
  # Skipping empty lines
  [ -z "$package" ] && continue
  # Skipping comments
  if [[ "$package" == \#* ]]; then
    continue
  fi
  echo "Testing $package"
  if [[ "$package" == "meteor-file" || "$package" == "crypto" ]]; then
    # A special case for meteor-file and crypto which requires Blob polyfill on PhantomJS
    PACKAGES="blob;$package" make test
    exit_code=$?
  else
    PACKAGES="$package" make test
    exit_code=$?
  fi
  if [ $exit_code -ne 0 ]; then
    EXIT_CODE=$exit_code
  fi
  # Cleanup
  killall -KILL node
done < .meteor/packages

# Exit
exit $EXIT_CODE
