class Migration extends Document.ModifyGeneratedFieldsMigration
  name: "Modifying displayName field dependencies"
  fields: ['displayName']

Person.addMigration new Migration()
