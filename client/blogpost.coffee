Meteor.subscribe 'blog-posts'

Template.indexBlogPosts.post_url = ->
  BlogPost.documents.findOne()?.post_url

Template.indexBlogPosts.total_post_count = ->
  BlogPost.documents.findOne()?.total_post_count

Template.indexBlogPosts.posts_exist = ->
  return !!BlogPost.documents.findOne()
