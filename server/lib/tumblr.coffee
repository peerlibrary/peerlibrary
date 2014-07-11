# This code loads PeerLibrary's blog posts from Tumblr and stores them as
# BlogPosts so that we can show latest blog post link on PeerLibrary index page

UPDATE_INTERVAL = 30 * 60 * 1000 # ms
TUMBLR_REQUEST_INTERVAL = 500 # ms
# According to Tumblr API documentation, maximum number of posts we can get from
# Tumblr in one request is 20, see https://www.tumblr.com/docs/en/api/v2
TUMBLR_POST_COUNT_LIMIT = 20
TUMBLR_BASIC_PARAMS =
  # We do not really need this info, but if we can have it...
  reblog_info: true
  notes_info: true
  # So that we do not have to convert from HTML to text ourselves
  filter: 'text'

if Meteor.settings?.tumblr
  baseHostname = Meteor.settings.tumblr.baseHostname
  apiKey = Meteor.settings.tumblr.apiKey

  tumblrApiPosts = (params) ->
    params = _.defaults params, TUMBLR_BASIC_PARAMS, api_key: apiKey
    url = "https://api.tumblr.com/v2/blog/#{ baseHostname }/posts"
    # We return JSON data directly
    HTTP.get(url, params: params).data

  # Converts object attribute names from underscore to camel case
  mapToCamelCase = (obj) ->
    if _.isArray obj
      _.map obj, mapToCamelCase
    else if not _.isObject obj
      obj
    else
      result = {}
      for key, value of obj
        camelCaseKey = key.replace /(\_[a-z])/gi, (match) -> match.charAt(1).toUpperCase()
        result[camelCaseKey] = mapToCamelCase value
      result

  getTumblrPostsPage = (offset) ->
    data = tumblrApiPosts
      offset: offset
      limit: TUMBLR_POST_COUNT_LIMIT
    throw new Error "Tumblr API error: #{ util.inspect data.meta }" unless data.meta.status is 200
    data.response.posts

  updatingTumblr = false
  @updateTumblr = ->
    try
      return if updatingTumblr
      updatingTumblr = true

      seenTumblrIds = []

      loop
        posts = getTumblrPostsPage seenTumblrIds.length
        break unless posts.length

        for post in posts
          post = mapToCamelCase post
          # We remove reblog key because it can often change and we would be unnecessary updating updatedAt
          post = _.omit post, 'reblogKey'

          # We are interested only in published blog posts
          continue if post.state isnt 'published'

          # Upsert combines foreignId with tumblr field when inserting
          {numberAffected, insertedId} = BlogPost.documents.upsert
            foreignId: post.id
          ,
            $set:
              tumblr: post
          BlogPost.documents.update insertedId, $set: createdAt: moment.utc().toDate() if insertedId

          seenTumblrIds.push post.id

        Meteor._sleepForMs TUMBLR_REQUEST_INTERVAL

      BlogPost.documents.remove
        'tumblr.id':
          $nin: seenTumblrIds

    finally
      updatingTumblr = false

  updateTumblrBackgroundLoop = ->
    try
      updateTumblr()
    catch error
      Log.error "Updating Tumblr blog posts error: #{ error }"
    Meteor.setTimeout updateTumblrBackgroundLoop, UPDATE_INTERVAL

  Meteor.startup ->
    # We defer first iteration of the loop so that we do not block startup
    Meteor.defer updateTumblrBackgroundLoop
