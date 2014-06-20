class @BlogPost extends BlogPost
  @PUBLISH_FIELDS: ->
    fields:
      post_url: 1
      total_post_count: 1

# TODO: Adjust cache update interval
CACHE_UPDATE_INTERVAL = 10000 # ms

updateCache = ->
  # If there is no Tumblr API key just return.
  # That way cache will stay empty. To client it
  # will look like there are no blog posts.
  return unless Meteor.settings.private.thumblr.apikey

  Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL
  apikey = Meteor.settings.private.thumblr.apikey
  url = "http://api.tumblr.com/v2/blog/peerlibrary.tumblr.com/posts?api_key=" + apikey
  try
    posts = HTTP.get url,
      timeout: 60000 # ms
  catch err
    # TODO: Handle errors
    return

  # There is only one latest post in the collection  
  cachedPost = BlogPost.documents.findOne()
  loadedPost = posts.data.response.posts[0]

  if !!cachedPost and loadedPost.id == cachedPost.id
    # Latest blog post is unchanged
    return

  # Add total post count to post
  loadedPost.total_post_count = posts.data.response.blog.posts

  BlogPost.documents.insert loadedPost

  # Remove old cached post from collection if there was one
  if !!cachedPost
    BlogPost.documents.remove
      id: cachedPost.id

updateCache()

Meteor.publish 'blog-posts', ->
  BlogPost.documents.find {}, BlogPost.PUBLISH_FIELDS()
 
