class Migration extends Document.MinorMigration
  name: "Adding searchResults field"

  # Client-only

Person.addMigration new Migration()
