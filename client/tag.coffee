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

# Optional tag document
Handlebars.registerHelper 'tagReference', (tagId, tag, options) ->
  tag = Tag.documents.findOne tagId unless tag

  # TODO: We want to display tags customized to the user, but store them with the ID
  # TODO: Maybe we could return from localPath also referenceSlug as provided in URL and use that as what we display to the user as a fallback
  text: "##{ tagId }"
