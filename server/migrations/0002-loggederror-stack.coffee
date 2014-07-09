class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding stack field"
  fields: ['stack']

LoggedError.addMigration new Migration()
