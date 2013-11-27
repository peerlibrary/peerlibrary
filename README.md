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

To add all tools provided by Meteor into your environment, add `~/.meteor/tools/latest/bin` to your
environment `PATH` variable. For example, by running:

    export PATH=~/.meteor/tools/latest/bin:$PATH

To add tools to you shell permanently, run:

    echo 'export PATH=~/.meteor/tools/latest/bin:$PATH' >> ~/.bash_profile

Maybe on your system you have to add the lien to `~/.profile` file instead.

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

From a cloned PeerLibrary repository then run a development instance of PeerLibrary:

    mrt

And open [http://localhost:3000/](http://localhost:3000/), which is an address of
your local development instance.

To demo the tool, you will need to populate your instance of the database with publications. Go to
[http://localhost:3000/admin](http://localhost:3000/admin). Here you will see a series of
buttons in the center of the screen that will allow you to cache publications.
Click on the second button, _Sync arXiv metadata_, to begin the syncing process. The process
will automatically proceed to caching and processing PDFs. Publications that make it all
the way through "processing" will be searchable at your [http://localhost:3000/](http://localhost:3000/).

Note: If you must stop the process midway through the metadata-cache-proccessing pipeline, you can
click the button in the admin interface for the process which you previously left off on.

### Troubleshooting ###

Sometimes when installing dependencies, Meteor will throw the following error:

    npm ERR! cb() never called!
    npm ERR! not ok code 0

This just means that there was a timeout while downloading a dependency, probably because of
a networking issue. Just retry.

If you get the following error:

    npm http 404 https://registry.npmjs.org/esprima/1.1.0-dev
    npm ERR! Error: version not found: 1.1.0-dev : esprima/1.1.0-dev

This error can occur because a development version of the `esprima` package is
installed among the dependencies, and `npm` gets confused with versions when upgrading. You should just the delete old
version with the command:

    rm -rf ~/.meteorite/packages/pdf.js

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

See the [Contributing](https://github.com/peerlibrary/peerlibrary/wiki/Contributing) section of our wiki for more
details and ideas.
