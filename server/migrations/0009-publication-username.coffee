class Migration extends Document.AddSyncedFieldsMigration
  name: "Adding user.username to authors"

Publication.addMigration new Migration()
