class @Tag extends Tag
  @Meta
    name: 'Tag'
    replaceParent: true

  # We allow passing the tag slug if caller knows it
  @pathFromId: (tagId, slug) ->
    assert _.isString tagId

    tag = @documents.findOne tagId

    return Meteor.Router.tagPath tag._id, (tag.slug ? slug) if tag

    Meteor.Router.tagPath tagId, slug

  path: =>
    @constructor.pathFromId @_id, @slug

  route: =>
    source: @constructor.verboseName()
    route: 'tag'
    params:
      tagId: @_id
      tagSlug: @slug

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (tagId, tag) ->
    assert _.isString tagId

    tag = @documents.findOne tagId unless tag
    assert tagId, tag._id if tag

    # TODO: We want to display tags customized to the user, but store them with the ID
    # TODO: Maybe we could return from localPath also referenceSlug as provided in URL and use that as what we display to the user as a fallback
    _id: tagId # TODO: Remove when we will be able to access parent template context
    text: "##{ tagId }"

  reference: =>
    @constructor.reference @_id, @

Tracker.autorun ->
  tagId = Session.get 'currentTagId'

  if tagId
    Meteor.subscribe 'tag-by-id', tagId

Template.tag.helpers
  tag: ->
    Tag.documents.findOne
      _id: Session.get 'currentTagId'

Template.registerHelper 'isTag', ->
  @ instanceof Tag

Template.registerHelper 'tagPathFromId', _.bind Tag.pathFromId, Tag

Template.registerHelper 'tagReference', _.bind Tag.reference, Tag
