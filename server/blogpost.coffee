class @BlogPost extends BlogPost
  @Meta
    name: 'BlogPost'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields:
      'tumblr.postUrl': 1
      'tumblr.title': 1
      'tumblr.caption': 1

Meteor.publish 'latest-blog-post', ->
  BlogPost.documents.find
    $or: [
      'tumblr.title':
        $exists: true
        $nin: ['', null]
    ,
      'tumblr.caption':
        $exists: true
        $nin: ['', null]
    ]
  ,
    limit: 1
    sort:
      'tumblr.timestamp': -1
    fields: BlogPost.PUBLISH_FIELDS().fields

BlogPost.Meta.collection._ensureIndex
  foreignId: 1
,
  unique: 1
