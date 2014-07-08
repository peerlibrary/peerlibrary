class Migration extends Document.AddAutoFieldsMigration
  name: "Adding inGroups field"
  fields: ['inGroups']

Person.addMigration new Migration()
