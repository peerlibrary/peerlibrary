PeerLibrary
===========

Capturing the global conversation on scholarly literature.

http://peerlibrary.org/ | http://blog.peerlibrary.org/ | [@PeerLibrary](https://twitter.com/PeerLibrary)

* [GitHub](https://github.com/peerlibrary/peerlibrary)
* [Wiki](https://github.com/peerlibrary/peerlibrary/wiki)
* [Development mailing list](http://lists.peerlibrary.org/lists/info/dev)
* IRC at #rawpotato @ [Freenode](http://freenode.net/)

Development installation
------------------------

PeerLibrary is built upon the [Meteor platform](http://www.meteor.com/). You can install it with:

    curl https://install.meteor.com | sh

If you do not have [node.js](http://nodejs.org) installed on your system, you can use one
provided by Meteor. To add it into your environment, add `~/.meteor/tools/latest/bin` to
your environment `PATH` variable. For example, by running:

    export PATH=~/.meteor/tools/latest/bin:$PATH

To add tools to you shell permanently, run:

    echo 'export PATH=~/.meteor/tools/latest/bin:$PATH' >> ~/.bash_profile

Maybe on your system you have to add the line to `~/.profile` file instead.

PeerLibrary requires additional Meteor packages which are provided through
[Meteorite](http://oortcloud.github.com/meteorite/), a Meteor package manager.
Install it as well:

    npm install -g meteorite
    
### Other requirements to run PeerLibrary ###

On first run, PeerLibrary compiles and locally installs additional libraries.
[Cairo](http://cairographics.org/) graphic library is required for this and you
might have to setup your system so that it can be successfully compiled.

On Mac OS X you can get Cairo by installing [X11](http://xquartz.macosforge.org/) and
run the following before you run `mrt` to configure environment:

    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig

To be able to compile libraries, you need [Xcode](https://developer.apple.com/xcode/)
with command line tools installed (from _Preferences_ > _Downloads_ > _Components_),
and `pkg-config` as well. The latter you can install using [Homebrew](http://brew.sh/)
([MacPorts](https://www.macports.org/) also works, if you prefer it).

On Debian you can install:

    sudo aptitude install libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

### Run it! ###

From a recursively cloned PeerLibrary repository (`git clone --recursive ...`) then run a development instance of PeerLibrary:

    mrt

And open [http://localhost:3000/](http://localhost:3000/), which is an address of
your local development instance, to start an installation wizard process in which you
create an admin user (which has username `admin`). After you create an admin
user, PeerLibrary will reload.

To demo the tool, you will need to populate your instance of the database with publications.
Log in as `admin` and go to [http://localhost:3000/admin](http://localhost:3000/admin).
Click on the _Initialize database with sample data_ button, to initialize the database with
the same publications from [arXiv](http://arxiv.org/). It will fetch metadata, cache a few PDFs
and process them. Publications will be searchable at your [http://localhost:3000/](http://localhost:3000/).

### Troubleshooting ###

Sometimes when installing dependencies, Meteor will throw the following error:

    npm ERR! cb() never called!
    npm ERR! not ok code 0

This just means that there was a timeout while downloading a dependency, probably because of
a networking issue. Just retry.

If you have not cloned recursively (`git clone --recursive ...`), you will at some point get a such or similar error:

    While building package `blob`:
    error: File not found: Blob/Blob.js

Or similar errors for other packages, you just have to manually initialize git submodules we are using:

    git submodule update --init --recursive

If you are getting Stylus errors like:

    error: Stylus compiler error: client/css/_viewer.styl:2

    failed to locate @import file variables.styl

You are not running `mrt` in the top-level directory of PeerLibrary. This is a [bug in Meteor](https://github.com/meteor/meteor/issues/1655).

If you notice that `mrt` command disappeared is this because you probably updated Meteor.
You have to reinstall Meteorite (`npm install -g meteorite`).

### Debug mode ###

To run PeerLibrary in the debug mode, you can run it with debug settings:

    mrt --settings=settings-debug.json

The debug mode currently does not do much, just shows how Meteor is redrawing browser content. So unless
you are trying to optimize PeerLibrary browser content redrawing performance, there is no need to run in
the debug mode.

Contributing
------------

PeerLibrary is currently in active development where we are creating
basic architecture. Major code refactoring and rewrites are thus common.
Nevertheless, you are invited to join the development, but please understand
that things might be changing under your feet so it is probably useful to
discuss planned contributions in advance.

See the [CONTRIBUTING](https://github.com/peerlibrary/peerlibrary/blob/master/CONTRIBUTING.md) file for more
details and ideas.
