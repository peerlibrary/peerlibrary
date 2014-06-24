class @BlogPost extends BlogPost
  @totalPosts = 0
  @PUBLISH_FIELDS: ->
    fields:
      postUrl: 1
      totalPosts: 1

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

  # Constructs request URL using params
  _request: (params) ->
    # params:
    #       method -> string
    #                 API method to call
    #       args -> object (optional)
    #               arguments to be passed to API method
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

# Sync Tumblr posts with local collection
syncPosts = (count, offset) ->
  # count -> Number of posts to load
  # offset -> First post offset (optional)
  return unless count
  offset = 0 unless offset
  limit = Math.min count, TUMBLR_POST_COUNT_LIMIT

  try
    response = Tumblr.get
      method: 'posts'
      args:
        limit: limit
        offset: offset
  catch err
    Log.error "Cache update failed: " + err
    return

  for post in response.data.response.posts
    remotePost = mapToCamelCase post
    localPost = BlogPost.documents.findOne
      id: remotePost.id

    # We add total post count to document so that client
    # can easily read it
    remotePost['totalPosts'] = BlogPost.totalPosts

    # We mark document as updated so that it doesn't
    # get deleted
    remotePost['updated'] = 1

    if !localPost
      BlogPost.documents.insert remotePost
    else
      BlogPost.documents.update localPost._id,
        $set: remotePost

  # Since number of posts that can be loaded in one request is limited
  # by Tumblr, function calles itself again if we want to load more posts
  syncPosts count - limit, offset + limit

# Updates blog post cache and starts a timeout loop to keep it updated
updateCache = ->
  try
    response = Tumblr.get
      method: 'info'
  catch err
    Log.error "Connecting to Tumblr failed: " + err
    return

  totalPosts = response.data.response.blog.posts
  BlogPost.totalPosts = totalPosts
  syncPosts totalPosts

  # Remove all non-updated documents from collection
  BlogPost.documents.remove
    updated: 0

  # Reset updated flag on all documents
  BlogPost.documents.update {},
    $set:
      updated: 0
  ,
    multi: 1

  Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL

Meteor.startup ->
  updateCache()

Meteor.publish 'latest-blog-post', ->
  BlogPost.documents.find {},
    limit: 1
    sort:
      timestamp: -1
    BlogPost.PUBLISH_FIELDS()

