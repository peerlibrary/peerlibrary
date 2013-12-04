# We use local collection on the server side because we do not really want to store this into the database
collectionName = if Meteor.isServer then null else 'Statistics'

@Statistics = new Meteor.Collection collectionName, transform: (doc) => new @StatisticsData doc

class @StatisticsData extends Document
  # countPublications: number of publications in the database
  # countPersons: number of people in the database
  # minPublicationDate: date of the earliest publication in the database
  # maxPublicationDate: date of the latest publication in the database

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Statistics
