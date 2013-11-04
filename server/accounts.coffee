Accounts.onCreateUser (options, user) ->
  try
    personId = Random.id()

    user.person =
      _id: personId

    person =
      _id: personId
      user:
        _id: user._id
        username: user.username
      slug: Person.Meta.fields.slug.generator(_id: personId, user: user)[1]
      gravatarHash: Person.Meta.fields.gravatarHash.generator(user)[1]

    _.extend person, _.pick(options.profile or {}, 'foreNames', 'lastName', 'work', 'education', 'publications')

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
