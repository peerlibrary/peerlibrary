#!/bin/bash

exit_code=0

# We run tests for each package separately, otherwise they can interfere with each other
while read package; do
  # Skipping empty lines
  [ -z "$package" ] && continue
  # Skipping comments
  if [[ "$package" == \#* ]]; then
    continue
  fi
  echo "Testing $package"
  if [[ "$package" == "meteor-file" ]]; then
    # A special case for meteor-file which requires Blob polyfill on PhantomJS
    PACKAGES="blob;$package" make test
  else
    PACKAGES="$package" make test
  fi
  if [ $? -ne 0 ]; then
    exit_code=$?
  fi
  # Cleanup
  killall -KILL node
done < .meteor/packages

# Exit
exit $exit_code
