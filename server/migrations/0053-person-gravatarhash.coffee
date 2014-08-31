class Migration extends Document.ModifyGeneratedFieldsMigration
  name: "Changing gravatarHash generator"
  fields: ['gravatarHash']

Person.addMigration new Migration()
