Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Annotations.find
    'publication._id': publicationId
  ,
    sort: [
      ['page', 'asc']
    ]