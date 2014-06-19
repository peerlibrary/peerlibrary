Template.accessIcon.iconName = ->
  switch @access
    when Publication.ACCESS.OPEN then 'icon-public'
    when Publication.ACCESS.CLOSED then 'icon-closed'
    when Publication.ACCESS.PRIVATE then 'icon-private'
    else assert false

Template.accessText.accessText = ->
  switch @access
    when Publication.ACCESS.OPEN then "open access"
    when Publication.ACCESS.CLOSED then "closed access"
    when Publication.ACCESS.PRIVATE then "private"
    else assert false

Template.member.documentIsPerson = ->
  @ instanceof Person

Template.member.documentIsGroup = ->
  @ instanceof Group

Template.memberAdd.documentIsPerson = Template.member.documentIsPerson
Template.memberAdd.documentIsGroup = Template.member.documentIsGroup

Template.memberAdd.noLinkDocument = ->
  # Because we cannot access parent templates we're modifying the data with an extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @noLink = true
  @
