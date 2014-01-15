# Only go to new path if we are not already there, to not
# make unnecessary entries in browser's history
Meteor.Router.toNew: (newPath) =>
  Meteor.Router.to newPath unless newPath is document.location.pathname
