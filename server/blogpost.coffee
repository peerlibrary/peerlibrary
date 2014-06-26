class @BlogPost extends BlogPost
  @totalPosts = 0
  @PUBLISH_FIELDS: ->
    fields:
      postUrl: 1
      totalPosts: 1

# TODO: Adjust cache update interval
CACHE_UPDATE_INTERVAL = 10000 # ms

TUMBLR_REQUEST_INTERVAL = 500 # ms
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
syncPosts = (params) ->
  # params:
  #       count -> Number of posts to load
  #       offset -> First post offset (optional)
  #       callback -> Callback function (optional)
  callback = (->) unless callback
  unless params.count
    params.callback()
    return
  params.offset = 0 unless params.offset
  limit = Math.min params.count, TUMBLR_POST_COUNT_LIMIT

  try
    response = Tumblr.get
      method: 'posts'
      args:
        limit: limit
        offset: params.offset
  catch err
    Log.error "Cache update failed: " + err
    return

  status = response.data.meta.status
  if status != 200
    message = response.data.meta.message
    Log.error 'Tumblr API error ' + status + ': ' + message
    return
  
  for post in response.data.response.posts
    # We remove internally used attributes from JSON object
    remotePost = mapToCamelCase _.omit post, ['_id', '_schema', 'updated']
    localPost = BlogPost.documents.findOne
      id: remotePost.id

    # We mark document as updated so that it doesn't
    # get deleted
    remotePost['updated'] = true

    if !localPost
      BlogPost.documents.insert remotePost
    else
      BlogPost.documents.update localPost._id,
        $set: remotePost

  # Since number of posts that can be loaded in one request is limited
  # by Tumblr, function calles itself again if we want to load more posts
  Meteor.setTimeout ->
    syncPosts
      count: params.count - limit
      offset: params.offset + limit
      callback: params.callback
  ,
    TUMBLR_REQUEST_INTERVAL

# Updates blog post cache and starts a timeout loop to keep it updated
updateCache = ->
  try
    response = Tumblr.get
      method: 'info'
  catch err
    Log.error 'Connecting to Tumblr failed: ' + err
    Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL
    return

  status = response.data.meta.status
  if status != 200
    message = response.data.meta.message
    Log.error 'Tumblr API error ' + status + ': ' + message
  else
    totalPosts = response.data.response.blog.posts
    BlogPost.totalPosts = totalPosts
    Meteor.setTimeout ->
      syncPosts
        count: totalPosts
        callback: ->
          # Remove all non-updated documents from collection
          BlogPost.documents.remove
            updated: 0
        
          # Reset updated flag on all documents
          BlogPost.documents.update {},
            $set:
              updated: 0
          ,
            multi: 1
    ,
      TUMBLR_REQUEST_INTERVAL

  Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL

Meteor.startup ->
  updateCache()

Meteor.publish 'latest-blog-post', ->
  BlogPost.documents.find {},
    limit: 1
    sort:
      timestamp: -1
    BlogPost.PUBLISH_FIELDS()

