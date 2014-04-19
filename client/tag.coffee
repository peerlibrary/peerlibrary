Deps.autorun ->
  tagId = Session.get 'currentTagId'

  if tagId
    Meteor.subscribe 'tag-by-id', tagId

Template.tag.tag = ->
  Tag.documents.findOne
    _id: Session.get 'currentTagId'
