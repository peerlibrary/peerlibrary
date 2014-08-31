class Migration extends Document.AddReferenceFieldsMigration
  name: "Adding the first user's e-mail"

Person.addMigration new Migration()
