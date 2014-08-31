class Migration extends Document.AddReferenceFieldsMigration
  name: "Adding user.username to authors"

Publication.addMigration new Migration()
