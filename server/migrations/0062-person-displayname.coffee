class Migration extends Document.ModifyGeneratedFieldsMigration
  name: "Modifying displayName field dependencies and making it has value only for registered users"
  fields: ['displayName']

Person.addMigration new Migration()
