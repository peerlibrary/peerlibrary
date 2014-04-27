Deps.autorun ->
  tagId = Session.get 'currentTagId'

  if tagId
    Meteor.subscribe 'tag-by-id', tagId

Template.tag.tag = ->
  Tag.documents.findOne
    _id: Session.get 'currentTagId'

# We allow passing the tag slug if caller knows it
Handlebars.registerHelper 'tagPathFromId', (tagId, slug, options) ->
  tag = Tag.documents.findOne tagId

  return Meteor.Router.tagPath tag._id, tag.slug if tag

  Meteor.Router.tagPath tagId, slug
