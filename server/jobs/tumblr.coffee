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

class @TumblrJob extends Job
  constructor: (data) ->
    super

    # We throw a fatal error to stop retrying a job if settings are not
    # available anymore, but they were in the past when job was added
    throw new @constructor.FatalJobError "Tumblr settings missing" unless Meteor.settings?.tumblr?.baseHostname and Meteor.settings?.tumblr?.apiKey

  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'low'
      retry:
        wait: UPDATE_INTERVAL
      repeat:
        wait: UPDATE_INTERVAL
      delay: UPDATE_INTERVAL / 2
      save:
        cancelRepeats: true

  _tumblrApiPosts: (params) =>
    params = _.defaults params, TUMBLR_BASIC_PARAMS, api_key: Meteor.settings.tumblr.apiKey
    url = "https://api.tumblr.com/v2/blog/#{ Meteor.settings.tumblr.baseHostname }/posts"
    # We return JSON data directly
    HTTP.get(url, params: params).data

  # Converts object attribute names from underscore to camel case
  _mapToCamelCase: (obj) =>
    if _.isArray obj
      _.map obj, @_mapToCamelCase
    else if not _.isObject obj
      obj
    else
      result = {}
      for key, value of obj
        camelCaseKey = key.replace /(\_[a-z])/gi, (match) -> match.charAt(1).toUpperCase()
        result[camelCaseKey] = @_mapToCamelCase value
      result

  _getTumblrPostsPage: (offset) =>
    data = @_tumblrApiPosts
      offset: offset
      limit: TUMBLR_POST_COUNT_LIMIT
    throw new Error "Tumblr API error: #{ util.inspect data.meta }" unless data.meta.status is 200
    data.response.posts

  run: =>
    seenTumblrIds = []
    insertedTumblrIds = []

    loop
      posts = @_getTumblrPostsPage seenTumblrIds.length
      break unless posts.length

      for post in posts
        post = @_mapToCamelCase post
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
        if insertedId
          BlogPost.documents.update insertedId, $set: createdAt: moment.utc().toDate()
          insertedTumblrIds.push post.id

        seenTumblrIds.push post.id

      Meteor._sleepForMs TUMBLR_REQUEST_INTERVAL

    BlogPost.documents.remove
      'tumblr.id':
        $nin: seenTumblrIds

    # Result
    seen: seenTumblrIds
    inserted: insertedTumblrIds

Job.addJobClass TumblrJob

if Meteor.settings?.tumblr
  Meteor.startup ->
    # Start a periodic job
    new TumblrJob().enqueue()
