
Template.member.entityIsPerson = ->
  @ instanceof Person

Template.member.entityIsGroup = ->
  @ instanceof Group

Template.memberAdd.entityIsPerson = Template.member.entityIsPerson
Template.memberAdd.entityIsGroup = Template.member.entityIsGroup

Template.memberAdd.noLinkEntity = ->
  # Because we cannot access parent templates we're modifying the data with an extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @noLink = true
  @

