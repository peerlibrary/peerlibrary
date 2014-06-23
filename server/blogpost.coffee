class @BlogPost extends BlogPost
  @PUBLISH_FIELDS: ->
    fields:
      postUrl: 1
      postNumber: 1

# TODO: Adjust cache update interval
CACHE_UPDATE_INTERVAL = 10000 # ms

TUMBLR_BLOG = 'peerlibrary.tumblr.com'
# According to Tumblr API documentation,
# maxiumum number of posts we can get from
# Tumblr in one request is 20.
# (https://www.tumblr.com/docs/en/api/v2)
TUMBLR_POST_COUNT_LIMIT = 20

# Tumblr API wrapper
Tumblr =
  _url: 'http://api.tumblr.com/v2/blog/' + TUMBLR_BLOG + '/'

  _request: (params) ->
    if !params?.method
      throw Error 'API method not set'
    key = Meteor.settings.private?.tumblr?.apikey
    if !key
      throw Error 'Tumblr API key not set'

    result = @_url + params.method + '?api_key=' + key
    if params.args
      for key, value of params.args
        result += '&' + key + '=' + value
    return result

  get: (params) ->
    HTTP.get @_request params

# Converts object attribute names from underscore to camel case
mapToCamelCase = (post) ->
  result = {}
  for key, value of post
    camelCaseKey = key.replace /(\_[a-z])/g,
      (match) ->
        match.charAt(1).toUpperCase()
    result[camelCaseKey] = value
  return result

# Loads posts from Tumblr
loadPosts = (count, offset) ->
  # count -> Number of posts to load
  # offset -> Start post number (optional)
  return unless count > 0
  offset = 0 unless offset
  cachedPostCount = BlogPost.documents.find().count()

  try
    response = Tumblr.get
      method: 'posts'
      args:
        limit: Math.min count, TUMBLR_POST_COUNT_LIMIT
        offset: offset
  catch err
    # TODO: Handle errors
    return

  for post in response.data.response.posts
    post.postNumber = cachedPostCount + count--
    postExists = !!BlogPost.documents.findOne
      id: post.id
    if not postExists
      BlogPost.documents.insert mapToCamelCase post

  # Since number of posts that can be loaded in one request is limited
  # by Tumblr, function calles itself again if we want to load more posts
  loadPosts count, offset + TUMBLR_POST_COUNT_LIMIT

# Updates blog post cache and starts a timeout loop to keep it updated
updateCache = ->
  try
    response = Tumblr.get
      method: 'info'
  catch err
    # TODO: Handle errors
    return

  cachedPostCount = BlogPost.documents.find()?.count()
  newPostCount = response.data.response.blog.posts

  if newPostCount > cachedPostCount
    loadPosts newPostCount - cachedPostCount

  Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL

Meteor.startup ->
  updateCache()

Meteor.publish 'latest-blog-post', ->
  postCount = BlogPost.documents.find().count()
  BlogPost.documents.find
    postNumber: postCount
  ,
    BlogPost.PUBLISH_FIELDS
  ,
    limit: 1

