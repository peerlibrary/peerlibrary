if Meteor.settings?.APM?.AppID and Meteor.settings?.APM?.AppSecret
  Meteor.startup ->
    # Connect Meteor to Meteor APM (https://meteorapm.com/)
    Apm.connect Meteor.settings.APM.AppID, Meteor.settings.APM.AppSecret
