class Migration extends Document.RenameFieldsMigration
  name: "Renaming temporaryFilename field to importingId"
  fields:
    temporaryFilename: 'importingId'

Publication.addMigration new Migration()
