class Migration extends Document.UpdateAllMinorMigration
  name: "Adding user.username to authors"

Publication.addMigration new Migration()
