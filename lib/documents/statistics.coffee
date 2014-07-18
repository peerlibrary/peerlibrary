class @Statistics extends BaseDocument
  # countPublications: number of publications in the database
  # countPersons: number of people in the database
  # countHighlights: number of highlights in the database
  # countAnnotations: number of annotations in the database
  # countGroups: number of groups in the database
  # countCollections: number of collections in the database
  # minPublicationDate: date of the earliest publication in the database
  # maxPublicationDate: date of the latest publication in the database

  @Meta
    name: 'Statistics'
    # We use local collection on the server side because we do not really want to store this into the database
    collection: if Meteor.isServer then null else 'Statistics'
