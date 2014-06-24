class @BlogPost extends Document
  # blogName: string, short name used to uniquely identify a blog
  # id: string, post's unique ID
  # postUrl: string, location of the post
  # type: string, type of post
  # timestamp: time of the post, in seconds since the epoch
  # date: GMT date and time of the post, as a string
  # format: string, post format (html or markdown)
  # reblogKey: string, key used to reblog this post
  # tags: array, tags applied to the post
  # bookmarklet: boolean, indicates whether the post was created via the Tumblr bookmarklet
  # mobile: boolean, indicates whether the post was created via mobile/email publishing
  # sourceUrl: string, the URL for the source of the content (for quotes, reblogs, etc.)
  # sourceTitle: string, The title of the source site
  # liked: boolean, indicates if a user has already liked a post or not
  # state: string, indicates the current state of the post
  # totalPosts: the total number of post available for this request
  # updated: boolean, indicates if post existed on last cache update

  @Meta
    name: 'BlogPost'

