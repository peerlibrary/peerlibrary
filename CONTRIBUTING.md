Contibuting to PeerLibrary
==========================

General ways to contribute to the development of PeerLibrary:
* Report bugs or tell us about features you are missing by opening [tickets](https://github.com/peerlibrary/peerlibrary/issues/new) or commenting them.
* Contribute to the PeerLibrary source code.
* Help us test PeerLibrary.
* Read (and contribute to) our [wiki](https://github.com/peerlibrary/peerlibrary/wiki) and other documentation.
* If you have your favorite open access journal or repository not yet integrated into PeerLibrary, add support for it. This goes especially for possible non-English open access journals or repositories we might not even know about. You can just [open a ticket for it](https://github.com/peerlibrary/peerlibrary/issues/new) to let us know.
* Advocate at your local university to open its publications to be able to integrate into PeerLibrary.

Reporting bugs
--------------

If you have found a bug in PeerLibrary, file a bug report in [our issue tracker](https://github.com/peerlibrary/peerlibrary/issues/new). If the issue contains sensitive information or raises a security concern, e-mail security at peerlibrary.org instead, which will page the security team.

PeerLibrary has many moving parts, and it is often difficult to reproduce a bug based on a vague description. If you want somebody to be able to fix a bug (or verify a fix that you have contributed), the best way is:
* Find minimal and exact steps needed to reproduce the bug.
* Describe what you expected to happen and what happened instead.
* Specify what version of PeerLibrary you are using (your own local development version, beta version, public version). Check the PeerLibrary footer for exact version information.
* Provide as much as you can about the environment you are using (operating system, browser, are you behind any proxy, are you on campus or off campus).
* Make and attach a screenshot or screenshots relevant to the bug you are reporting. You can use [LICEcap](http://www.cockos.com/licecap/con) to create a live capture of the bug as a GIF file and attach it to the issue. Do not forget to obfuscate any possibly sensitive or private information visible there.

By making it as easy as possible for others to reproduce your bug, you make it easier for your bug to be fixed. We are not always able to tackle issues opened without a reproduction recipe. In those cases we will close them with a pointer to this wiki section and a request for more information.

And never forget, we will **never ask you for your password** when debugging bugs you have reported or are experiencing. If you ever recieve such request, it is a [phishing attack](https://en.wikipedia.org/wiki/Phishing) on you and somebody is trying to gain unauthorized access to your account. You should report it to security at peerlibrary.org immediatelly. You should not trust such requests for your password even if they seem to be coming from security at peerlibrary.org address.

Contributing code
-----------------

If you would like to start contributing code and are searching for some ideas:
* Check the [roadmap and milestones](https://github.com/peerlibrary/peerlibrary/issues/milestones) and related open tickets. See especially the `for-new-contributors` label and [Parallel milestone](https://github.com/peerlibrary/peerlibrary/issues?labels=for+new+contributors&milestone=9&page=1&state=open). Parallel milestone contains all tickets which are not time critical and are thus suitable for new contributors. If you would like to work on a ticket, assign yourself to that ticket and make a comment about your intent.
* Check `TODO` comments in the code: there are quite a number of them which are of the "here is a dirty hack, do a real implementation" kind, which are a good way to start contributing. Some other TODOs will require waiting/coordination for other things to be done first.
* While reading the code if you do not understand anything, feel free to ask and then contribute a comment describing the code so that the next person will understand.
* Sometimes there are stylistic or other non-critical issues with the code. Feel free to improve it.

We are using GitHub and pull requests for development. If pull requests are new to you, see [this tutorial](https://help.github.com/articles/fork-a-repo) to find out how to fork and contribute to our repository.

Before submitting a pull request, make sure that it follows these guidelines:
* Make sure that your branch is based off of the `development` branch. The `development` branch is where active development happens. We cannot merge non-trivial patches off `master` branch. See [PeerLibrary development model](https://github.com/peerlibrary/peerlibrary/wiki/Development-Model) for more details. (`development` branch not yet available)
* Sign the contributor's agreement. (not yet available)
* Follow the PeerLibrary [code style guide](https://github.com/peerlibrary/peerlibrary/wiki/Code-Style).
* Get familiar with our [code internals](https://github.com/peerlibrary/peerlibrary/wiki/Code-Internals) and [principles](https://github.com/peerlibrary/peerlibrary/wiki/Principles).
* Limit yourself to one feature or bug fix per pull request.
* Name your branch to match the feature/bug fix that you are submitting.
* Write clear, descriptive commit messages.
* Describe your pull request in as much detail as possible: why this pull request is important enough for us to consider, what changes it contains, what you had to do to get it to work, how you tested it, etc. Be detailed but be clear: use bullets, examples if needed, and simple, straightforward language.
* Pull requests should in general include:
 * All necessary code changes but not more than those
 * Documentation (can be through code comments and/or end-user documentation/help for new features)
 * Tests (if pull request is fixing a bug, tests should fail without the pull request and succeed with it; if pull request is adding a new feature, tests should test all aspects of this new feature)
* Consider writing a [blog post](http://blog.peerlibrary.org/) about you pull request as well. You have all rights to brag about it!

If you are working on a big ticket item, please check in on our [development mailing list](http://lists.peerlibrary.org/lists/info/dev) first, or at least comment/open a related ticket first describing your plan. We would hate to have to steer you in a different direction after you have already put in a lot of hard work.

