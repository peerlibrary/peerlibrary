class Migration extends Document.MinorMigration
  name: "Adding user.username to Publication's authors"

Publication.addMigration new Migration()
