CACHE_UPDATE_INTERVAL = 10000 # ms
# TODO: Get our own API key
THUMBLR_API_KEY = "fuiKNFp9vQFvjLNvx4sUwti4Yb5yGutBN4Xh10LXZhhRKjWlV4"

updateCache = ->
  Meteor.setTimeout updateCache, CACHE_UPDATE_INTERVAL
  try
    posts = HTTP.get "http://api.tumblr.com/v2/blog/peerlibrary.tumblr.com/posts?api_key=" + THUMBLR_API_KEY,
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
  loadedPost.totalPostCount = posts.data.reponse.posts
  BlogPost.documents.insert loadedPost

  # Remove old cached post from collection if there was one
  if !!cachedPost
    BlogPost.documents.remove
      id: cachedPost.id

updateCache()

Meteor.publish 'blog-posts', ->
  BlogPost.documents.find()
 
