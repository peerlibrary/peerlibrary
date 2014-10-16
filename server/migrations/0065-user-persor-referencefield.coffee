class Migration extends Document.AddReferenceFieldsMigration
  name: "adding displayname to person in user class"

User.addMigration new Migration()
