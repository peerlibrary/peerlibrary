__meteor_runtime_config__.INSTALL = @INSTALL = Meteor.users.find({}, limit: 1).count() == 0
