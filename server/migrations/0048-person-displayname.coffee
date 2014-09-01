class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding displayName field"
  fields: ['displayName']

Person.addMigration new Migration()
