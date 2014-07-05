class Migration extends Document.UpdateAllMinorMigration
  name: "Adding the first user's e-mail"

Person.addMigration new Migration()
