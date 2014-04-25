// Make a global variable to export Scribe to Meteor
Scribe = require('scribe');

Scribe.plugins = {};
Scribe.plugins['blockquote-command'] = require('scribe-plugin-blockquote-command');
Scribe.plugins['heading-command'] = require('scribe-plugin-heading-command');
Scribe.plugins['keyboard-shortcuts'] = require('scribe-plugin-keyboard-shortcuts');
Scribe.plugins['sanitizer'] = require('scribe-plugin-sanitizer');
Scribe.plugins['toolbar'] = require('scribe-plugin-toolbar');
