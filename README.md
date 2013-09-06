PeerLibrary
===========

Enriching the experience of open access scholarly literature.

A project of the [Open Access Initiative at Berkeley](http://oa.berkeley.edu/).

http://peerlibrary.org/ | http://blog.peerlibrary.org/ | [@PeerLibrary](https://twitter.com/PeerLibrary)

* [Development mailing list](http://lists.peerlibrary.org/lists/info/dev)
* IRC at #rawpotato @ [Freenode](http://freenode.net/)

Development installation
------------------------

PeerLibrary is built upon the [Meteor platform](http://www.meteor.com/). You can install it with:

    curl https://install.meteor.com | sh

To add all tools provided by Meteor into your environment, add `~/.meteor/tools/latest/bin/` to your
environment `PATH` variable. For example, by running:

    export PATH="~/.meteor/tools/latest/bin/:$PATH"

To add tools to you shell permanently, run:

    echo 'export PATH="~/.meteor/tools/latest/bin/:$PATH"' >> ~/.bash_profile

PeerLibrary requires additional Meteor packages which are provided through
[Meteorite](http://oortcloud.github.com/meteorite/), a Meteor package manager.
Install it as well:

    npm install -g meteorite

From a cloned PeerLibrary repository then run a development instance of PeerLibrary:

    mrt

And open [http://localhost:3000/](http://localhost:3000/), which is an address of
your local development instance.

### Requirements ###

On first run, PeerLibrary compiles and locally installs additional libraries.
[Cairo](http://cairographics.org/) graphic library is required for this and you
might have to setup your system so that it can be successfully compiled.

On Mac OS X you can get Cairo by installing [X11](http://xquartz.macosforge.org/) and
run the following before you run `mrt` to configure environment:

    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig

To be able to compile libraries, you need [Xcode](https://developer.apple.com/xcode/) and
`pkg-config` as well. The latter you can install using [Homebrew](http://brew.sh/) or
[MacPorts](https://www.macports.org/).

On Debian you can install:

    aptitude install libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

### Debug mode ###

To run PeerLibrary in the debug mode, you can run it with debug settings:

    mrt --settings=settings-debug.json

The debug mode currently does not do much, just shows how Meteor is redrawing browser content. So unless
you are trying to optimize PeerLibrary browser content redrawing performance, there is no need to run in
the debug mode.

Contributing
------------

PeerLibrary is currently in an active development where we are creating
basic architecture. Major code refactoring and rewrites are thus common.
Nevertheless you are invited to join the development but please understand
that things might be changing under your feet so it is probably useful to
discuss planned contributions in advance.

For ideas what to contribute you can:
* check the [roadmap and milestones](https://github.com/peerlibrary/peerlibrary/issues/milestones)
  and related open issues
* check `TODO` comments in the code: there are quite some of them which are of "here is a
  dirty hack, do a real implementation" kind, those are a good start to contribute;
  while some other have to wait for other things to be done first
* while reading the code if you do not understand anything, feel free to ask and then
  contribute a comment describing the code so that the next person will understand
* check [our ideas for possible features](https://github.com/peerlibrary/peerlibrary/wiki/Features);
  this list is really just brainstorming and we have not yet decided which features we
  really want and when, but it is a good start to get you thinking about possible ways
  to contribute, especially if there is some feature you would really like to have;
  feel free to add additional ideas
* if you have your favorite open access journal or repository not yet integrated into
  PeerLibrary, add support for it; this goes especially for possible non-English open
  access journals or repositories we might not even know about; you can just
  [open an issue for it](https://github.com/peerlibrary/peerlibrary/issues/new) to let
  us know
* advocate at your local university to open its publications to be able to integrate
  into PeerLibrary
