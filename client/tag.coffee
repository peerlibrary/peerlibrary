class @Tag extends Tag
  @Meta
    name: 'Tag'
    replaceParent: true

  # We allow passing the tag slug if caller knows it
  @pathFromId: (tagId, slug, options) ->
    assert _.isString tagId
    # To allow calling template helper with only one argument (slug will be options then)
    slug = null unless _.isString slug

    tag = @documents.findOne tagId

    return Meteor.Router.tagPath tag._id, (tag.slug ? slug) if tag

    Meteor.Router.tagPath tagId, slug

  path: =>
    @constructor.pathFromId @_id, @slug

  route: =>
    route: 'tag'
    params:
      tagId: @_id
      tagSlug: @slug

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (tagId, tag, options) ->
    assert _.isString tagId
    # To allow calling template helper with only one argument (tag will be options then)
    tag = null unless tag instanceof @

    tag = @documents.findOne tagId unless tag
    assert tagId, tag._id if tag

    # TODO: We want to display tags customized to the user, but store them with the ID
    # TODO: Maybe we could return from localPath also referenceSlug as provided in URL and use that as what we display to the user as a fallback
    _id: tagId # TODO: Remove when we will be able to access parent template context
    text: "##{ tagId }"

  reference: =>
    @constructor.reference @_id, @

Deps.autorun ->
  tagId = Session.get 'currentTagId'

  if tagId
    Meteor.subscribe 'tag-by-id', tagId

Template.tag.tag = ->
  Tag.documents.findOne
    _id: Session.get 'currentTagId'

Handlebars.registerHelper 'tagPathFromId', _.bind Tag.pathFromId, Tag

Handlebars.registerHelper 'tagReference', _.bind Tag.reference, Tag
