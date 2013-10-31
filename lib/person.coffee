@Persons = new Meteor.Collection 'Persons', transform: (doc) => new @Person doc

class @Person extends Document
  # user: (null if unregistered)
  #   _id
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # created: creation timestamp
  # foreNames
  # lastName
  # work
  #   position (e.g. Professor of Theoretical Physics)
  #   institution (e.g. University of California, Berkeley)
  #   startYear (e.g. 2011)
  #   endYear null if current
  # education
  #   degree (e.g. PhD)
  #   concentration (e.g. Social Anthropology)
  #   institution
  #   thesis: publication id - TODO: Define reference
  #   advisor: person id - TODO: Define reference
  #   startYear
  #   endYear: null if ongoing
  #   completed: true if degree granted
  # publications: list of
  #   _id: authored publication's id

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Persons
    fields:
      user: @ReferenceField User, ['username'], false
      publications: [@ReferenceField Publication]
      slug: @GeneratedField 'self', ['user.username'], (fields) ->
        if fields.user?.username
          [fields._id, fields.user.username]
        else
          [fields._id, fields._id]
      gravatarHash: @GeneratedField User, [emails: {$slice: 1}, 'person'], (fields) ->
        address = fields.emails?[0]?.address
        return [null, undefined] unless fields.person?._id and address

        crypto = Npm.require 'crypto'
        [fields.person._id, crypto.createHash('md5').update(address).digest('hex')]
