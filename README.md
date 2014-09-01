PeerLibrary
===========

Facilitating the global conversation on academic literature.

[https://peerlibrary.org/](https://peerlibrary.org/) | [http://blog.peerlibrary.org/](http://blog.peerlibrary.org/) | [@PeerLibrary](https://twitter.com/PeerLibrary)

* [GitHub](https://github.com/peerlibrary/peerlibrary)
* [Wiki](https://github.com/peerlibrary/peerlibrary/wiki)
* [Development mailing list](http://lists.peerlibrary.org/lists/info/dev)
* IRC at #rawpotato @ [Freenode](http://freenode.net/)

Development installation
------------------------

PeerLibrary is built upon the [Meteor platform](http://www.meteor.com/). You can install it with:

    curl http://meteor.peerlibrary.org/ | sh

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

On first run, PeerLibrary compiles and locally installs additional Meteor packages,
some of them have non-Meteor dependencies. The following libraries have
to be available on your system for PeerLibrary to successfully run:

 * [Cairo](http://cairographics.org/) graphic library
 * [FreeType](http://www.freetype.org/)
 * [Pango](http://www.pango.org/)
 * [pkg-config](http://www.freedesktop.org/wiki/Software/pkg-config/)
 * [giflib](http://giflib.sourceforge.net/)
 * [libjpeg](http://www.ijg.org)

On Mac OS X you can get Cairo by installing [X11](http://xquartz.macosforge.org/) (Pango
and FreeType are already available on the system) and run the following before you
run `mrt` to configure the environment:

    export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig

To be able to compile Meteor packages, you need [Xcode](https://developer.apple.com/xcode/)
with command line tools installed (from _Preferences_ > _Downloads_ > _Components_).

You can install `pkg-config`, `giflib`, and `libjpeg` using [Homebrew](http://brew.sh/)
([MacPorts](https://www.macports.org/) also works, if you prefer it):

    brew install pkg-config giflib libjpeg

On Debian you can install all dependencies by:

    sudo aptitude install libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++

### Run it! ###

Recursively clone a PeerLibrary repository:

    git clone --recursive https://github.com/peerlibrary/peerlibrary.git

This will give you the latest development version of PeerLibrary (`development` branch). The latest
stable version is in the `master` branch.

And then run a development instance of PeerLibrary:

    mrt

And open [http://localhost:3000/](http://localhost:3000/), which is an address of
your local development instance, to start an installation wizard process in which you
create an admin user (which has username `admin`). After you create an admin
user, PeerLibrary will reload.

To demo the tool, you will need to populate your instance of the database with publications.
Log in as `admin` and go to _Admin dashboard_ ([http://localhost:3000/admin](http://localhost:3000/admin)).
Click on the _Initialize database with sample data_ button, to initialize the database with
the same publications from [arXiv](http://arxiv.org/). It will fetch metadata, cache a few PDFs
and process them. Publications will be searchable at your [http://localhost:3000/](http://localhost:3000/).

For more information on configuring your installation, see [settings](https://github.com/peerlibrary/peerlibrary/wiki/Settings).

### ArXiv publications ###

To load and use [arXiv](http://arxiv.org/) publications, open _Admin dashboard_
([http://localhost:3000/admin](http://localhost:3000/admin)) and click on _Sync arXiv metadata_
button first and after it loads all the metadata, click _Sync arXiv PDF cache_ button to load
all PDFs. After the caching finishes and PDFs are processed you will be able to search and open
arXiv publications in PeerLibrary.

**arXiv is a huge repository and loading all the publications takes a lot of space (few 100 GBs) and time.
You probably do not want to do this. It consumes arXiv resources and costs you money. Use _Initialize
database with sample data_ to get a small sample of arXiv publications.**

You will need [AWS](http://aws.amazon.com/) `accessKeyId` and `secretAccessKey` which you have to put into
your `settings.json` file. All PDF transfer costs will be [billed against this account](http://arxiv.org/help/bulk_data_s3).

### Free Speech Movement publications ###

To load and use [Free Speech Movement](http://bancroft.berkeley.edu/FSM/) publications, open _Admin dashboard_
([http://localhost:3000/admin](http://localhost:3000/admin)) and click on _Sync FSM metadata_ button first
and after it loads all the metadata, click _Sync FSM cache_ button to load all the TEI textual documents.
After the caching finishes you will be able to search and open FSM publications in PeerLibrary.

You will need [FSM API](http://digitalhumanities.berkeley.edu/hackfsm/api) `appId` and `appKey` which you
have to put into your `settings.json` file.

### Troubleshooting ###

Sometimes when installing dependencies, Meteor will throw the following error:

    npm ERR! cb() never called!
    npm ERR! not ok code 0

This just means that there was a timeout while downloading a dependency, probably because of
a networking issue. Just retry.

If you have not cloned recursively (if you forgot `--recursive` in `git clone --recursive https://github.com/peerlibrary/peerlibrary.git`), you will at some point get a such or similar error:

    While building package `blob`:
    error: File not found: Blob/Blob.js

Or similar errors for other packages, you just have to manually initialize git submodules we are using:

    git submodule update --init --recursive

If you are getting an error like:

    Error: Cannot find module '../build/Release/canvas'

Then there is an issue compiling the [node-canvas](https://github.com/LearnBoost/node-canvas) dependency. Check
if you have all required non-Meteor dependencies installed and retry by removing the whole `meteor-pdf.js` package
and running `mrt` again:

    rm -rf ~/.meteorite/packages/pdf.js/

If you are getting Stylus errors like:

    error: Stylus compiler error: client/css/_viewer.styl:2

    failed to locate @import file variables.styl

You are not running `mrt` in the top-level directory of PeerLibrary. This is a [bug in Meteor](https://github.com/meteor/meteor/issues/1655).

If you notice that `mrt` command disappeared is this because you probably updated Meteor.
You have to reinstall Meteorite (`npm install -g meteorite`).

Contributing
------------

PeerLibrary is currently in active development where we are creating
basic architecture. Major code refactoring and rewrites are thus common.
Nevertheless, you are invited to join the development, but please understand
that things might be changing under your feet so it is probably useful to
discuss planned contributions in advance.

See the [CONTRIBUTING](https://github.com/peerlibrary/peerlibrary/blob/master/CONTRIBUTING.md) file for more
details and ideas.
