class Migration extends Document.MinorMigration
  name: "Adding invitedEmail field"

  # Client-only

Person.addMigration new Migration()
