ADMIN_USER_ID = 'NfEBPKH6GLYHuSJXJ'
ADMIN_PERSON_ID = 'exYYMzAP6a2swNRCx'

INVITE_SECRET = Random.id()

class @User extends User
  @Meta
    name: 'User'
    replaceParent: true

  # Returns true if account has any service associated with it,
  # like password set. It returns false if account has been created
  # for an invitation but never claimed.
  isRegistered: =>
    # Check if password is set
    return true unless _.isEmpty _.omit(@services?.password, 'reset')

    # Otherwise check if some other service is set
    return true unless _.isEmpty _.omit(@services, 'password', 'resume')

    return false

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields:
      username: 1
      emails: 1
      settings: 1

  # A subset of public fields used for automatic publishing
  @PUBLISH_AUTO_FIELDS: ->
    # username and emails fields (in addition to profile field which
    # we do not use) are pushed already by Meteor accounts-base package.
    # We list them here to more or less just document them. Few
    # additional fields are pushed as well, used for login purposes.
    fields: _.pick @PUBLISH_FIELDS().fields, [
      'username'
      'emails'
      'settings'
    ]

# With null name, the record set is automatically sent to all connected clients
Meteor.publish null, ->
  return unless @userId

  # No need for requireReadAccessSelector because we are sending data to the user themselves
  User.documents.find
    _id: @userId
  ,
    User.PUBLISH_AUTO_FIELDS()

Meteor.methods
  'invite-user': methodWrap (email, message) ->
    validateArgument 'email', email, EMail
    validateArgument 'message', message, Match.Optional String

    # We require that user inviting is logged in
    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    invitedUser = User.documents.findOne 'emails.address': email
    if invitedUser
      throw new Meteor.Error 400, "User is already a member." if invitedUser.isRegistered()
      userId = invitedUser._id
    else
      userId = Accounts.createUser
        email: email
        secret: INVITE_SECRET

    invited = Person.documents.findOne
      'user._id': userId

    assert invited

    Person.documents.update
      _id: invited._id
    ,
      # It is OK to add multiple invitations for the same inviter
      $push:
        invited:
          by:
            _id: person._id
          message: message?.trim() or null

    Accounts.sendEnrollmentEmail userId

    invited._id

  'reset-password-with-username': methodWrap (token, verifier, username) ->
    validateArgument 'token', token, String
    validateArgument 'verifier', verifier, Object
    validateArgument 'username', username, String,
    User.validateUsername username, 'username'

    # We call Meteor's internal resetPassword method
    newUser = Meteor.call 'resetPassword', token, verifier
    Meteor.call 'set-username', username

    newUser

  'set-username': methodWrap (username) ->
    validateArgument 'username', username, String
    User.validateUsername username, 'username'

    throw new Meteor.Error 401, "User not signed in." unless Meteor.person()

    updatedCount = User.documents.update
      _id: Meteor.userId()
      username:
        $exists: false
    ,
      $set:
        username: username
    throw new Meteor.Error 400, "Username already set." unless updatedCount is 1

  'pause-background': methodWrap (paused) ->
    validateArgument 'paused', paused, Boolean

    throw new Meteor.Error 401, "User not signed in." unless Meteor.person()

    User.documents.update
      _id: Meteor.userId()
    ,
      $set:
        'settings.backgroundPaused': paused

Accounts.onCreateUser methodWrap (options, user) ->
  # Idea is that only server side knows invite secret and we can
  # based on that differentiate between onCreateUser checks because
  # user is registering and checks because user has been invited
  throw new Meteor.Error 400, "Invalid secret." if options.secret and options.secret isnt INVITE_SECRET

  if user.username is 'admin'
    user._id = ADMIN_USER_ID
    personId = ADMIN_PERSON_ID
  else
    personId = Random.id()
    # Person _id must not match any existing User username otherwise our queries for
    # Person documents querying both _id and slug would return multiple documents
    while User.documents.exists(username: personId)
      personId = Random.id()

  # We are verifying things here and not in a validateNewUser hook to prevent creation
  # of a profile document and then failure later on when validating through validateNewUser

  # TODO: Our error messages end with a dot, but client-side (Meteor's) do not

  # Check username unless onCreateUser is called because user has been invited
  User.validateUsername user.username, 'user.username' unless options.secret

  throw new Meteor.Error 400, "Invalid email address." unless user.username is 'admin' or EMAIL_REGEX.test user.emails?[0]?.address

  throw new Meteor.Error 400, "Invalid email address." if user.emails?.length > 1

  # A race condition, but better than nothing. Otherwise it fails later on when creating an
  # user document, but person document has already been created and is not cleaned up.
  # We do not really care if users are reusing their email address, we just do not want errors
  # later on when MongoDB unique index fails. So we are not checking here an email in a
  # case insensitive manner, or normalize it in some other way (like removing Gmail +suffix).
  throw new Meteor.Error 400, "Email already exists." if user.username isnt 'admin' and User.documents.exists 'emails.address': user.emails?[0]?.address

  user.person =
    _id: personId

  createdAt = moment.utc().toDate()
  person =
    _id: personId
    user:
      # TODO: This sometimes throw a warning because we are creating a link before user document is really created, all this code should run after user document is created
      _id: user._id
      username: user.username
    slug: Person.Meta.fields.slug.generator(_id: personId, user: user)[1]
    gravatarHash: Person.Meta.fields.gravatarHash.generator(user)[1]
    createdAt: createdAt
    updatedAt: createdAt

  _.extend person, _.pick(options.profile or {}, 'givenName', 'familyName')

  person = Person.applyDefaultAccess null, person

  try
    Person.documents.insert person
  catch error
    if error.name isnt 'MongoError'
      throw error
    # TODO: Improve when https://jira.mongodb.org/browse/SERVER-3069
    if /E11000 duplicate key error index:.*Persons\.\$slug/.test error.err
      throw new Meteor.Error 400, "Username already exists."
    throw error

  user

MAX_LINE_LENGTH = 68

# Formats text into lines of MAX_LINE_LENGTH width for pretty emails
wrap = (text, maxLength=MAX_LINE_LENGTH) ->
  lines = for line in text.split '\n'
    if line.length <= maxLength
      line
    else
      words = line.split ' '
      if words.length is 1
        line
      else
        ls = [words.shift()]
        for word in words
          if ls[ls.length - 1].length + word.length + 1 <= maxLength
            ls[ls.length - 1] += ' ' + word
          else
            ls.push word
        ls.join '\n'

  lines.join '\n'

indent = (text, amount) ->
  assert amount >= 0
  padding = (' ' for i in [0...amount]).join ''
  lines = for line in text.split '\n'
    padding + line
  lines.join '\n'

wrapWithIndent = (text, indentAmount=2, wrapLength=MAX_LINE_LENGTH) ->
  # Wrap text to narrower width
  text = wrap text, wrapLength - indentAmount

  # Indent it to reach back to full width
  indent text, indentAmount

Accounts.emailTemplates.siteName = SITENAME
Accounts.emailTemplates.from = Meteor.settings?.from or "PeerLibrary <no-reply@peerlibrary.org>"

noReplyFrom = not Meteor.settings?.from or Meteor.settings?.fromNoReply

Accounts.emailTemplates.resetPassword.subject = (user) ->
  """[#{ Accounts.emailTemplates.siteName }] Password reset"""
Accounts.emailTemplates.resetPassword.text = (user, url) ->
  url = url.replace '#/', ''

  person = Meteor.person user._id

  # Construct email body
  parts = []

  parts.push """
  Hello #{ person.getDisplayName() }!

  This message was sent to you because you requested a password reset for your user account at #{ Accounts.emailTemplates.siteName } with username "#{ user.username }". If you have already done so or don't want to, you can safely ignore this email.

  Please click the link below and choose a new password:

  #{ url }

  Please also be careful to open a complete link. Your email client might have broken it into several lines.

  Your username, in case you have forgotten: #{ user.username }

  """

  unless noReplyFrom
    parts.push """

    If you have any problems resetting your password or have any other questions just reply to this email.

    """

  parts.push """

  Yours,


  #{ Accounts.emailTemplates.siteName }
  #{ Meteor.absoluteUrl() }
  """

  wrap parts.join ''

Accounts.emailTemplates.enrollAccount.subject = (user) ->
  invited = Meteor.person user._id,
    invited:
      # We assume that the last inviter is the one we want, not really a big problem if there was a race condition and we made a mistake
      $slice: -1 # Using $slice does not exclude other fields by itself

  # The first (0) and only element in the array is here the last inviter
  assert invited.invited?[0]?.by?._id

  person = Person.documents.findOne
    _id: invited.invited[0].by._id

  assert person

  """[#{ Accounts.emailTemplates.siteName }] #{ person.getDisplayName() } is inviting you to join them"""
Accounts.emailTemplates.enrollAccount.text = (user, url) ->
  url = url.replace '#/', ''
  url = url.replace 'enroll-account', 'accept-invitation'

  invited = Meteor.person user._id,
    invited:
      # We assume that the last inviter is the one we want, not really a big problem if there was a race condition and we made a mistake
      $slice: -1 # Using $slice does not exclude other fields by itself

  # The first (0) and only element in the array is here the last inviter
  assert invited.invited?[0]?.by?._id

  person = Person.documents.findOne
    _id: invited.invited[0].by._id

  assert person

  # Construct email body
  parts = []

  # We are forcing getDisplayName as all PeerDB generators
  # might not yet ran invited.displayName might be obsolete.
  parts.push """
  Hello #{ invited.getDisplayName true }!

  #{ Accounts.emailTemplates.siteName } is a website facilitating the global conversation on academic literature and #{ person.getDisplayName() } is inviting you to join the conversation with them
  """

  message = invited.invited[0].message
  if message
    parts.push """
    :

    #{ wrapWithIndent message }

    """
  else
    parts.push """
    .

    """

  parts.push """

  Please click the link below to accept the invitation and create an account:

  #{ url }

  If you have already done so or don't want to, you can safely ignore this email.

  Please also be careful to open a complete link. Your email client might have broken it into several lines.

  To learn more about #{ Accounts.emailTemplates.siteName }, visit:

  #{ Meteor.absoluteUrl() }

  """

  unless noReplyFrom
    parts.push """

    If you have any problems signing up or have any other questions just reply to this email.

    """

  parts.push """

  Yours,


  #{ Accounts.emailTemplates.siteName }
  #{ Meteor.absoluteUrl() }
  """

  wrap parts.join ''
