class Migration extends Document.PatchMigration
  name: "Making publications field a reverse reference"

  # Should not really change any database content

Person.addMigration new Migration()
