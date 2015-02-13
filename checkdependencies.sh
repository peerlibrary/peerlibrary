#!/bin/bash

# This script checks to see that all the dependencies are installed.
# It might not be very flexible as all it does is checks that the required
# directories are in the same place as they are on Mac OS X Yosemite.

if [ ! -d "/usr/X11" ]; then
  echo "X11 is not in /usr/X11."
fi
if [[ ! -d /Applications/Xcode.app/Contents/Developer ]]; then
  echo "You don't have the XCode Developer Tools."
  echo "Note after you download and install XCode, you still need to download the Developer Tools."
fi

if [ ! -d "$HOME/.meteor" ]; then
  echo "You haven't installed Meteor yet."
fi

if [[ ! ":$PATH:" == *":$HOME/.meteor/tools/latest/bin:"* ]]; then
  echo "You need to add $HOME/.meteor/tools/latest/bin to your path."
fi

if [ ! -d "$HOME/.meteorite" ]; then
  echo "you haven't installed meteorite yet"
fi

if [[ ! "$PKG_CONFIG_PATH" == "/opt/X11/lib/pkgconfig" ]]; then
  echo "You need to type export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig."
fi
