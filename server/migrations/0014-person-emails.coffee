class Migration extends Document.AddSyncedFieldsMigration
  name: "Adding the first user's e-mail"

Person.addMigration new Migration()
