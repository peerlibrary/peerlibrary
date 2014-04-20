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

    throw new Meteor.Error 400, "Username must be at least 3 characters long." unless user.username and user.username.length >= 3

    throw new Meteor.Error 400, "Username must contain only a-zA-Z0-9_- characters." unless USERNAME_REGEX.test user.username

    throw new Meteor.Error 400, "Username already exists." if user.username in FORBIDDEN_USERNAMES

    throw new Meteor.Error 400, "Invalid e-mail address." unless user.username is 'admin' or EMAIL_REGEX.test user.emails?[0]?.address

    throw new Meteor.Error 400, "Invalid e-mail address." if user.emails?.length > 1

    # A race condition, but better than nothing. Otherwise it fails later on when creating an
    # user document, but person document has already been created and is not cleaned up.
    throw new Meteor.Error 400, "Email already exists." if user.username isnt 'admin' and User.documents.findOne 'emails.address': user.emails?[0]?.address

    user.person =
      _id: personId

    person =
      _id: personId
      user:
        # TODO: This sometimes throw a warning because we are creating a link before user document is really created, all this code should run after user document is created
        _id: user._id
        username: user.username
      slug: Person.Meta.fields.slug.generator(_id: personId, user: user)[1]
      gravatarHash: Person.Meta.fields.gravatarHash.generator(user)[1]

    _.extend person, _.pick(options.profile or {}, 'givenName', 'familyName')

    person = Person.applyDefaultAccess null, person

    Person.documents.insert person

  catch error
    if error.name isnt 'MongoError'
      throw error
    # TODO: Improve when https://jira.mongodb.org/browse/SERVER-3069
    if /E11000 duplicate key error index:.*Persons\.\$slug/.test error.err
      throw new Meteor.Error 400, "Username already exists."
    throw error

  user

# With null name, the record set is automatically sent to all connected clients
Meteor.publish null, ->
  return unless @userId

  Person.documents.find
    'user._id': @userId
  ,
    fields: _.pick Person.PUBLIC_FIELDS().fields, Person.PUBLIC_AUTO_FIELDS()

MAX_LINE_LENGTH = 68

wrap = (text) ->
  lines = for line in text.split '\n'
    if line.length <= MAX_LINE_LENGTH
      line
    else
      words = line.split ' '
      if words.length is 1
        line
      else
        ls = [words.shift()]
        for word in words
          if ls[ls.length - 1].length + word.length + 1 <= MAX_LINE_LENGTH
            ls[ls.length - 1] += ' ' + word
          else
            ls.push word
        ls.join '\n'

  lines.join '\n'

Accounts.emailTemplates.siteName = Meteor.settings?.siteName or "PeerLibrary"
Accounts.emailTemplates.from = Meteor.settings?.from or "PeerLibrary <no-reply@peerlibrary.org>"
Accounts.emailTemplates.resetPassword.subject = (user) ->
  """[#{ Accounts.emailTemplates.siteName }] Password reset"""
Accounts.emailTemplates.resetPassword.text = (user, url) ->
  url = url.replace '#/', ''

  person = Meteor.person user._id

  # When MAIL_URL is not set e-mail is printed to the console, but without empty
  # newlines. Do not worry, when sending e-mail for real empty newlines are there.
  wrap """
  Hello #{ person.displayName() }!

  This message was sent to you because you requested a password reset for your user account at #{ Accounts.emailTemplates.siteName } with username "#{ user.username }". If you have already done so or don't want to, you can safely ignore this e-mail.

  Please click the link below and choose a new password:

  #{ url }

  Please also be careful to open a complete link. Your e-mail client might have broken it into several lines.

  Your username, in case you have forgotten: #{ user.username }

  If you have any problems resetting your password or have any other questions just reply to this e-mail.

  Yours,


  #{ Accounts.emailTemplates.siteName }
  #{ Meteor.absoluteUrl() }
  """
