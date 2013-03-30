PeerLibrary
===========

Enriching the experience of open access scholarly literature.

A project of the [Open Access Initiative at Berkeley](http://oa.berkeley.edu/).

Development installation
------------------------

PeerLibrary is built upon the [Meteor platform](http://www.meteor.com/). You can install it with:

    curl https://install.meteor.com | sh

Additional packages require [Meteorite](http://oortcloud.github.com/meteorite/):

    npm install -g meteorite

And then run:

    mrt

And open [http://localhost:3000/](http://localhost:3000/).

### Requirements ###

On first run, PeerLibrary compiles and locally installs additional libraries.
[Cairo](http://cairographics.org/) graphic library is required for this and you
might have to configure environment properly so that it can be successfully
compiled. For example, on Mac OS X:

    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig
