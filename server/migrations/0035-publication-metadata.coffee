class Migration extends Document.RemoveFieldsMigration
  name: "Removing metadata field"
  fields:
    metadata: false

Publication.addMigration new Migration()
