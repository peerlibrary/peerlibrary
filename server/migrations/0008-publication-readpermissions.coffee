class Migration extends Document.MinorMigration
  name: "Adding readUsers and readGroups fields to Publication"

Publication.addMigration new Migration()
