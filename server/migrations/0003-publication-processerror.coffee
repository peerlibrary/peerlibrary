class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding processError field"
  fields: ['processError']

Publication.addMigration new Migration()
