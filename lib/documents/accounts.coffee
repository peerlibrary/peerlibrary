USERNAME_REGEX = /^[a-zA-Z0-9_-]+$/
FORBIDDEN_USERNAME_REGEX = /^(webmaster|root|peerlib.*|adm|admn|admin.+)$/i

class @User extends Document
  # createdAt: time of creation
  # updatedAt: time of last change
  # username: user's username
  # emails: list of
  #   address: e-mail address
  #   verified: is e-mail address verified
  # services: list of authentication/linked services
  # person:
  #   _id: id of related person document

  @Meta
    name: 'User'
    collection: Meteor.users
    fields: =>
      person: @ReferenceField Person
    triggers: =>
      updatedAt: UpdatedAtTrigger ['username', 'emails', 'person._id']

  @validateUsername = (username) ->
    throw new Meteor.Error 400, "Username must be at least 3 characters long." unless username and username.length >= 3

    throw new Meteor.Error 400, "Username must contain only a-zA-Z0-9_- characters." unless USERNAME_REGEX.test username

    throw new Meteor.Error 400, "Username already exists." if FORBIDDEN_USERNAME_REGEX.test username

    # Check for unique username in a case insensitive manner.
    # We do not have to escape username because we have already
    # checked that it contains only a-zA-Z0-9_- characters.
    throw new Meteor.Error 400, "Username already exists." if User.documents.findOne username: new RegExp "^#{ username }$", 'i'

    # Username must not match any existing Person _id otherwise our queries for
    # Person documents querying both _id and slug would return multiple documents
    throw new Meteor.Error 400, "Username already exists." if Person.documents.findOne _id: username

  @validatePassword = (password) ->
    throw new Meteor.Error 400, "Password must be at least 6 characters long." unless password and password.length >= 6
