class Migration extends Document.MinorMigration
  name: "Adding processError field to Publication"

Publication.addMigration new Migration()
