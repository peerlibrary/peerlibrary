class Migration extends Document.AddAutoFieldsMigration
  name: "Adding displayName field"
  fields: ['displayName']

Person.addMigration new Migration()
