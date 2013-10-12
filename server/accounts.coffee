crypto = Npm.require 'crypto'

Accounts.onCreateUser (options, user) ->
  try
    person =
      user:
        id: user._id
        username: user.username
      slug: user.username
      gravatarHash: crypto.createHash('md5').update(user.emails?[0]?.address).digest('hex')

    _.extend person, _.pick(options.profile or {}, 'foreNames', 'lastName', 'work', 'education', 'publications')

    personId = Persons.insert person
    user.person =
      id: personId

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
    'user.id': @userId
  ,
    fields: _.pick Person.PUBLIC_FIELDS().fields, Person.PUBLIC_AUTO_FIELDS()
