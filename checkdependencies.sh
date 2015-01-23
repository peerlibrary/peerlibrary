#!/bin/bash
# I spent a while struggling with errors until I realized I hadn't
# met all the dependencies. This script checks to see that all the dependencies
# are installed.
# It might have bugs as this is one of the first scripts I've ever written.
# It also might not be very flexible as all it does is checks that the required
# folders are in the same place as they are on my OSX Yosemitie
if [ ! -d "/usr/X11" ]; then
  echo "X11 is not in /usr/X11"
fi
if [[ ! -d /Applications/Xcode.app/Contents/Developer ]]; then
  echo "you don't have the xcode developer tools"
  echo "note after you download xcode,"
  echo "you still need to download the developer tools"
fi

if [ ! -d "$HOME/.meteor" ]; then
  echo "you haven't installed meteor yet"
fi
if [[ ! ":$PATH:" == *":$HOME/.meteor/tools/latest/bin:"* ]]; then
  echo "you need to add $HOME/.meteor/tools/latest/bin to your path"
fi

if [ ! -d "$HOME/.meteorite" ]; then
  echo "you haven't installed meteorite yet"
fi

if [[ ! "$PKG_CONFIG_PATH" == "/opt/X11/lib/pkgconfig" ]]; then
  echo "you need to type export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig"
fi
