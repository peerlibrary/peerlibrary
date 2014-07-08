class Migration extends Document.UpdateAllMinorMigration
  name: "Adding annotations field"

Publication.addMigration new Migration()
