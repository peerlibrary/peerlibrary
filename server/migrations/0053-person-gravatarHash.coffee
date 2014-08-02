class Migration extends Document.ModifyAutoFieldsMigration
  name: "Changing gravatarHash generator"
  fields: ['gravatarHash']

Person.addMigration new Migration()
