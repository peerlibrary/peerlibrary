if Meteor.settings.secretKey
  Crypto.SECRET_KEY = Meteor.settings.secretKey
else
  Log.warn "Secret key setting missing, using public one"
  Crypto.SECRET_KEY = "She sang beyond the genius of the sea. The water never formed to mind or voice, Like a body wholly body, fluttering Its empty sleeves; and yet its mimic motion Made constant cry, caused constantly a cry, That was not ours although we understood, Inhuman, of the veritable ocean."
