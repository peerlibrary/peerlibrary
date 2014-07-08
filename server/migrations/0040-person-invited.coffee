class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding invited field"
  fields: ['invited']

Person.addMigration new Migration()
