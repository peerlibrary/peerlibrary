// Make a global variable to export Scribe to Meteor
Scribe = require('scribe');

Scribe.plugins = {};
Scribe.plugins['blockquote-command'] = require('scribe-plugin-blockquote-command');
Scribe.plugins['curly-quotes'] = require('scribe-plugin-curly-quotes');
Scribe.plugins['link-prompt-command'] = require('scribe-plugin-link-prompt-command');
