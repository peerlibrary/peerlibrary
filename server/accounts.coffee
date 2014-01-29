ADMIN_USER_ID = 'NfEBPKH6GLYHuSJXJ'
ADMIN_PERSON_ID = 'exYYMzAP6a2swNRCx'

USERNAME_REGEX = /^[a-zA-Z0-9_-]+$/

FORBIDDEN_USERNAMES = [
  'webmster'
  'root'
  'peerlibrary'
  'administrator'
]

Accounts.onCreateUser (options, user) ->
  try
    if user.username is 'admin'
      user._id = ADMIN_USER_ID
      personId = ADMIN_PERSON_ID
    else
      personId = Random.id()

    # We are verifying things here and not in a validateNewUser hook to prevent creation
    # of a profile document and then failure later on when validating through validateNewUser

    # TODO: Our error messages end with a dot, but client-side (Meteor's) do not

    throw new Meteor.Error 403, "Username must be at least 3 characters long." unless user.username and user.username.length >= 3

    throw new Meteor.Error 403, "Username must contain only a-zA-Z0-9_- characters." unless USERNAME_REGEX.test user.username

    throw new Meteor.Error 403, 'Username conflicts with existing slug.' if user.username in FORBIDDEN_USERNAMES

    # TODO: Validate e-mail

    user.person =
      _id: personId

    person =
      _id: personId
      user:
        _id: user._id
        username: user.username
      slug: Person.Meta.fields.slug.generator(_id: personId, user: user)[1]
      gravatarHash: Person.Meta.fields.gravatarHash.generator(user)[1]

    _.extend person, _.pick(options.profile or {}, 'givenName', 'familyName')

    Persons.insert person

  catch e
    if e.name isnt 'MongoError'
      throw e
    # TODO: Improve when https://jira.mongodb.org/browse/SERVER-3069
    if /E11000 duplicate key error index:.*Persons\.\$slug/.test e.err
      throw new Meteor.Error 403, 'Username conflicts with existing slug.'
    throw e

  user

# With null name, the record set is automatically sent to all connected clients
Meteor.publish null, ->
  return unless @userId

  Persons.find
    'user._id': @userId
  ,
    fields: _.pick Person.PUBLIC_FIELDS().fields, Person.PUBLIC_AUTO_FIELDS()
