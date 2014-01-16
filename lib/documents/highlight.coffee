@Highlights = new Meteor.Collection 'Highlights', transform: (doc) => new @Highlight doc

class @Highlight extends Document
  # created: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   foreNames
  #   lastName
  # publication:
  #   _id: publication's id
  # quote: quote made by this highlight
  # target: open annotation standard compatible target information

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Highlights
    fields:
      author: @ReferenceField Person, ['slug', 'foreNames', 'lastName']
      publication: @ReferenceField Publication

Highlights.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check the target (try to apply it on the server)
    # TODO: Check that author really has access to the publication

    return false unless userId

    personId = Meteor.personId userId

    personId and doc.author._id is personId

# Misuse insert validation to add additional fields on the server before insertion
Highlights.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.created = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just adding fields
    false
