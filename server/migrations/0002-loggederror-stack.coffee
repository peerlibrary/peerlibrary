class Migration extends Document.MinorMigration
  name: "Adding stack field to LoggedError"

LoggedError.addMigration new Migration()
