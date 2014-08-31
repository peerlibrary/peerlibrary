class @BlogPost extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # foreignId: foreign ID of the blog post
  # tumblr: (a non-comprehensive list of fields)
  #   blogName: string, short name used to uniquely identify a blog
  #   id: number, post's unique ID
  #   postUrl: string, URL of the post
  #   type: string, type of post
  #   timestamp: time of the post, in seconds since the epoch
  #   date: GMT date and time of the post, as a string
  #   state: string, indicates the current state of the post
  #   format: string, post format (html or markdown)
  #   tags: array, tags applied to the post
  #   source: string, source description
  #   sourceUrl: string, the URL for the source of the content (for quotes, reblogs, etc.)
  #   sourceTitle: string, the title of the source site
  #   postAuthor: string, post's author
  #   shortUrl: shortened URL of the post
  #   noteCount: count of Tumblr notes (likes, reblogs, etc.)
  #   title: for text and link types, title of the post
  #   body: for text type, body of the post
  #   text: for quote type, text of the quote
  #   caption: for photo and video types, caption
  #   url: for link type, URL of the link
  #   description: for link type, description of the link

  @Meta
    name: 'BlogPost'
    triggers: =>
      updatedAt: UpdatedAtTrigger ['foreignId', 'tumblr'], true
