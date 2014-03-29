class @Annotation extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # access: 0 (private), 1 (public)
  # readUsers: if private access, list of users who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # body: annotation's body
  # publication:
  #   _id: publication's id
  # highlights: list of
  #   _id: highlight id
  # local (client only): is this annotation just a temporary annotation on the cliend side

  @Meta
    name: 'Annotation'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      readUsers: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      readGroups: [@ReferenceField Group, ['slug', 'name']]
      publication: @ReferenceField Publication, [], true, 'annotations'
      highlights: [@ReferenceField Highlight, [], true, 'annotations']

  @ACCESS:
    PRIVATE: ACCESS.PRIVATE
    PUBLIC: ACCESS.PUBLIC

  hasReadAccess: (person) =>
    return true if person?.isAdmin

    return true if @access is Annotation.ACCESS.PUBLIC

    # We assume @access is private here

    return false unless person?._id

    return true if person._id in _.pluck @readUsers, '_id'

    personGroups = _.pluck person?.inGroups, '_id'
    annotationGroups = _.pluck @readGroups, '_id'

    return true if _.intersection(personGroups, annotationGroups).length

    return false
