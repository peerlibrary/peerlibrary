class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding settings.backgroundPaused field"
  fields: ['settings.backgroundPaused']

User.addMigration new Migration()
