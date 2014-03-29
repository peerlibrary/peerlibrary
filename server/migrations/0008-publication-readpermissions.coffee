class Migration extends Document.MinorMigration
  name: "Adding readPersons and readGroups fields to Publication"

Publication.addMigration new Migration()
