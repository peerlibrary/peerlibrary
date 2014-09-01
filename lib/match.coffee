# From Meteor's random/random.js
@UNMISTAKABLE_CHARS = '23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz'
INVALID_ID_CHARS_REGEX = new RegExp "[^#{ UNMISTAKABLE_CHARS }]"
INVALID_SHA256_CHARS_REGEX = new RegExp '[^a-f0-9]'

@PositiveNumber = Match.Where (x) ->
  check x, Number
  x > 0

@NonEmptyString = Match.Where (x) ->
  check x, String
  x.trim().length > 0

@DocumentId = Match.Where (x) ->
  check x, String
  check x, Match.Where (y) -> y.length is 17
  not INVALID_ID_CHARS_REGEX.test x

@ObjectWithOnlyStrings = Match.Where (x) ->
  check x, Object
  for key, value of x
    check key, String
    check value, String

@MatchAccess = (access) ->
  values = _.values access
  Match.Where (a) ->
    check a, Number
    a in values

@SHA256String = Match.Where (x) ->
  check x, String
  check x, Match.Where (y) -> y.length is 64
  not INVALID_SHA256_CHARS_REGEX.test x

@EMail = Match.Where (x) ->
  check x, NonEmptyString
  EMAIL_REGEX.test x

# We provide our own optional that also allows null
@OptionalOrNull = (pattern) ->
  Match.Where (x) ->
    check x, Match.OneOf null, Match.Optional pattern
    true
