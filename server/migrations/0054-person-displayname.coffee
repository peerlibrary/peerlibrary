class Migration extends Document.ModifyAutoFieldsMigration
  name: "Modifying displayName field dependencies"
  fields: ['displayName']

Person.addMigration new Migration()
