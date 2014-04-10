class @Group extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # slug: slug for URL
  # name: name of the group
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Group'
    fields: =>
      slug: @GeneratedField 'self', ['name']
      members: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], true, 'inGroups']
