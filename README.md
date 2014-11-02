PeerLibrary
===========

Facilitating the global conversation on academic literature.

[https://peerlibrary.org/](https://peerlibrary.org/) | [http://blog.peerlibrary.org/](http://blog.peerlibrary.org/) | [@PeerLibrary](https://twitter.com/PeerLibrary) | [Facebook](https://www.facebook.com/PeerLibrary)

* [GitHub](https://github.com/peerlibrary/peerlibrary)
* [Development wiki](https://github.com/peerlibrary/peerlibrary/wiki)
* [Development tickets](https://github.com/peerlibrary/peerlibrary/issues)
* [Development mailing list](http://lists.peerlibrary.org/lists/info/dev)
* IRC at #peerlibrary @ [Freenode](http://freenode.net/)
* Email hello @ peerlibrary.org

_PeerLibrary outreach is [done in another repository](https://github.com/peerlibrary/outreach)._

Weekly meeting
--------------

Regular general weekly meeting is every Monday 8 PM PST. Meeting is open to really
everyone. Remote participation is possible using Google Hangout
[through permanently opened video session](https://plus.google.com/hangouts/_/calendar/YmVya2VsZXkuZWR1X2UyYTVhcWc4cXJnaWM2bnQ2ZDk0OG0yNXJnQGdyb3VwLmNhbGVuZGFyLmdvb2dsZS5jb20.kijreb7bhpl8qfkr7n9d549so4).
Additionally, join us on our IRC channel at that time for more information. We are also using our
IRC channel for a backchannel to the meeting. Notes are taken and sent to the mailing lists, and their
address follow the following format `http://pad.peerlibrary.org/p/meeting-YYYY-MM-DD`.

Development installation
------------------------

### Prerequisites ###

PeerLibrary is built upon the [Meteor platform](http://www.meteor.com/). You can install it with:

    curl https://install.meteor.com/ | sh

You need [node.js](http://nodejs.org) installed on your system. On Mac OS X you can use
[Homebrew](http://brew.sh/) to install it:

    brew install node

On Debian, run:

    sudo apt-get install nodejs nodejs-legacy npm

PeerLibrary uses [Meteorite](http://oortcloud.github.com/meteorite/). Install it:

    npm install -g meteorite

Maybe you will have to run it with `sudo`:

    sudo npm install -g meteorite

### Run it! ###

Recursively clone a PeerLibrary repository:

    git clone --recursive https://github.com/peerlibrary/peerlibrary.git

This will give you the latest development version of PeerLibrary (`development` branch). The latest
stable version is in the `master` branch.

Run a development instance of PeerLibrary from the **PeerLibrary top-level directory**:

    mrt

Open [http://localhost:3000/](http://localhost:3000/), which is an address of
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

If you have not cloned recursively (if you forgot `--recursive` in `git clone --recursive https://github.com/peerlibrary/peerlibrary.git`), you will at some point get a such or similar error:

    While Building package `dom-text-mapper`:
    error: File not found: dom-text-matcher/lib/diff_match_patch/diff_match_patch_uncompressed.js
    error: File not found: dom-text-matcher/src/text_match_engines.coffee
    error: File not found: dom-text-mapper/src/dom_text_mapper.coffee
    error: File not found: dom-text-matcher/src/dom_text_matcher.coffee
    error: File not found: dom-text-mapper/src/page_text_mapper_core.coffee

Or similar errors for other packages, you just have to manually initialize git submodules we are using:

    git submodule update --init --recursive

If you are getting an errors like:

    TypeError: Object #<Object> has no method 'addExtraBodyHook

You are not running `mrt` from the top-level directory of PeerLibrary.

Contributing
------------

PeerLibrary is currently in active development where we are creating
basic architecture. Major code refactoring and rewrites are thus common.
Nevertheless, you are invited to join the development, but please understand
that things might be changing under your feet so it is probably useful to
discuss planned contributions in advance.

See the [CONTRIBUTING](https://github.com/peerlibrary/peerlibrary/blob/development/CONTRIBUTING.md)
file for more details and ideas.

You can also help with [PeerLibrary outreach, promotion, teaching, and community organizing](https://github.com/peerlibrary/outreach).
