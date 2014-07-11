class Migration extends Document.AddAutoFieldsMigration
  name: "Adding hasUser field"
  fields: ['hasUser']

Person.addMigration new Migration()
