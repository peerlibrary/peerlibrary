class Migration extends Document.MinorMigration
  name: "Adding inGroups field to Person"

Person.addMigration new Migration()
