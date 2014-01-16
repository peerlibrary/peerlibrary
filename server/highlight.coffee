Meteor.publish 'highlights-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Highlights.find
    'publication._id': publicationId
