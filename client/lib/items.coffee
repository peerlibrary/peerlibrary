Template.member.documentIsPerson = ->
  @ instanceof Person

Template.member.documentIsGroup = ->
  @ instanceof Group

Template.memberAdd.documentIsPerson = Template.member.documentIsPerson
Template.memberAdd.documentIsGroup = Template.member.documentIsGroup

Template.memberAdd.noLinkDocument = ->
  # When inline item is used inside a button, disable its hyperlink. We don't want an active link
  # inside a button, because the button itself provides an action that happens when clicking on it.

  # Because we cannot access parent templates we're modifying the data with an extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @noLink = true
  @
