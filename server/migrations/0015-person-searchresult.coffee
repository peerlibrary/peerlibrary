class Migration extends Document.MinorMigration
  name: "Adding searchResults field to Person"

  # Client-only

Person.addMigration new Migration()
