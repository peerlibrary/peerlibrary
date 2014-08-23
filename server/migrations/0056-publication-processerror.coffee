class Migration extends Document.RemoveFieldsMigration
  name: "Removing processError field"
  fields:
    processError: undefined

Publication.addMigration new Migration()
