Meteor.methods
  'newsletter-subscribe': methodWrap (email) ->
    validateArgument email, EMail, 'email'

    result = Meteor.http.post 'http://lists.peerlibrary.org/lists',
      params:
        list: 'news'
        action: 'subrequest'
        action_subrequest: 'subscribe'
        email: email

    throw new Meteor.Error 400, "Unknown error." unless result.statusCode is 200

    throw new Meteor.Error 400, "You are already subscribed to the newsletter." if /You are already subscribed to list/.test result.content

    throw new Meteor.Error 400, "Unknown error." unless /You requested a subscription to list/.test result.content
