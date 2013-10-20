Contibuting to PeerLibrary
==========================

General ways to contribute to the development of PeerLibrary:
* Report bugs or tell us about features you are missing by opening [tickets](https://github.com/peerlibrary/peerlibrary/issues/new) or commenting them.
* Contribute to the PeerLibrary source code.
* Help us test PeerLibrary.
* Read (and contribute to) our [wiki](https://github.com/peerlibrary/peerlibrary/wiki) and other documentation.
* If you have your favorite open access journal or repository not yet integrated into PeerLibrary, add support for it. This goes especially for possible non-English open access journals or repositories we might not even know about. You can just [open a ticket for it](https://github.com/peerlibrary/peerlibrary/issues/new) to let us know.
* Advocate at your local university to open its publications to be able to integrate into PeerLibrary.

Contributing code
-----------------

If you would like to start contributing code and are searching for some ideas:
* Check the [roadmap and milestones](https://github.com/peerlibrary/peerlibrary/issues/milestones) and related open tickets. See especially the `for-new-contributors` label. If you would like to work on a ticket, assign yourself to that ticket and make a comment about your intent.
* Check `TODO` comments in the code: there are quite a number of them which are of the "here is a dirty hack, do a real implementation" kind, which are a good way to start contributing. Some other TODOs will require waiting/coordination for other things to be done first.
* While reading the code if you do not understand anything, feel free to ask and then contribute a comment describing the code so that the next person will understand.
* Sometimes there are stylistic or other non-critical issues with the code. Feel free to improve it.

We are using GitHub and pull requests for development. If pull requests are new to you, see [this tutorial](https://help.github.com/articles/fork-a-repo) to find out how to fork and contribute to our repository.

Before submitting a pull request, make sure that it follows these guidelines:
* Make sure that your branch is based off of the `development` branch. The `development` branch is where active development happens. We cannot merge non-trivial patches off `master` branch. See [PeerLibrary development model](https://github.com/peerlibrary/peerlibrary/wiki/Development-Model) for more details.
* Sign the contributor's agreement. (not yet available)
* Follow the PeerLibrary [code style guide](https://github.com/peerlibrary/peerlibrary/wiki/Code-Style).
* Limit yourself to one feature or bug fix per pull request.
* Name your branch to match the feature/bug fix that you are submitting.
* Write clear, descriptive commit messages.
* Describe your pull request in as much detail as possible: why this pull request is important enough for us to consider, what changes it contains, what you had to do to get it to work, how you tested it, etc. Be detailed but be clear: use bullets, examples if needed, and simple, straightforward language.
* Pull requests should in general include:
 * All necessary code changes but not more than those
 * Tests (if pull request is fixing a bug, tests should fail without the pull request and succeed with it; if pull request is adding a new feature, tests should test all aspects of this new feature)
 * Documentation (can be through code comments and/or end-user documentation/help for new features)
* Consider writing a [blog post](http://blog.peerlibrary.org/) about you pull request as well. You have all rights to brag about it!

If you are working on a big ticket item, please check in on our [development mailing list](http://lists.peerlibrary.org/lists/info/dev) first, or at least comment/open a related ticket first describing your plan. We would hate to have to steer you in a different direction after you have already put in a lot of hard work.

