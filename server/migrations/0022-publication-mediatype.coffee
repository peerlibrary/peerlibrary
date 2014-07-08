class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding mediaType field"
  fields:
    mediaType: 'pdf'

  forward: (document, collection, currentSchema, newSchema) =>
    counts = super
    Storage.rename 'pdf', 'publication' if Storage.exists 'pdf'
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    counts = super
    Storage.rename 'publication', 'pdf' if Storage.exists 'publication'
    counts

Publication.addMigration new Migration()
