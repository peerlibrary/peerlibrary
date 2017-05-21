class Migration extends Document.AddReferenceFieldsMigration
  name: "Adding displayName to person"

User.addMigration new Migration()
