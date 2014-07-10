class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding createdRaw field"
  fields: ['createdRaw']

Publication.addMigration new Migration()
