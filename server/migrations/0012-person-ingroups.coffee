class Migration extends Document.UpdateAllMinorMigration
  name: "Adding inGroups field"

Person.addMigration new Migration()
