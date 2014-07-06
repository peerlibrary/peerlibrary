Meteor.startup ->
  # Allow exiting immediately after startup to allow starting
  # Meteor in a way to only update all NPM packages
  process.exit 0 if process.env.EXIT_ON_STARTUP
