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
compiled.

On Mac OS X you can get Cairo by installing
[X11](http://xquartz.macosforge.org/), `pkg-config`
([Homebrew](http://brew.sh/), [MacPorts](https://www.macports.org/)), and:

    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig

On Debian you can install:

    aptitude install libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

Contributing
------------

PeerLibrary is currently in an active development where we are creating
basic architecture. Major code refactoring and rewrites are thus common. Clear
roadmap has not yet been established. Nevertheless you are invited to join the
development but please understand that things might be changing under your feet
so it is probably useful to discuss planned contributions in advance. Open [a
GitHub issue](https://github.com/peerlibrary/peerlibrary/issues/new) or join us
on IRC at #rawpotato @ [Freenode](http://freenode.net/) or on a
[development mailing list](http://lists.peerlibrary.org/lists/info/dev).

For ideas what to contribute you can:
* check [list of open issues](https://github.com/peerlibrary/peerlibrary/issues?state=open)
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

In particular, we are currently searching for help with:
* natural language parsing of search queries (we want search to be similar to Facebook Graph Search)
  and mapping queries to supported filters
* full-text search and ranking of results, especially how to rank weight different filters,
  content vs. title and so on; if you want to try out your own idea how to help people find
  relevant publications, PeerLibrary could be a playground you searched for
* integrating Meteor with [ConcurrenTree](https://github.com/campadrenalin/ConcurrenTree)-like
  approach for rich-text real-time collaborative editor
