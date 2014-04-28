# This code allows PeerLibrary to expose e-mails of registered users in a way
# which is then possible to source into Sympa (https://www.sympa.org/), a
# mailing list manger. For Sympa configuration, see:
# http://www.sympa.org/manual/parameters-data-sources#include_remote_file

# TODO: Allow users to opt-out from this list and thus from the newsletter

# We expose e-mails only if it is explicitly enabled by providing HTTP basic
# authentication username and password (which is required to access the list).
# If you are using this, use HTTPS to protect username and password.
if Meteor.settings?.sympa?.username and Meteor.settings?.sympa?.password
  WebApp.connectHandlers.use('/sympa', connect.basicAuth(Meteor.settings.sympa.username, Meteor.settings.sympa.password))

  Meteor.Router.add '/sympa', 'GET', ->
    lines = Person.documents.find().map (person, index, cursor) ->
      # Process only registered users
      return '' unless person.user

      return '' unless person.email()

      "#{ person.email() } #{ person.displayName() }\n"

    [200, {'Content-Type': 'text/plain'}, lines.join('')]
