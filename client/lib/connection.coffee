disconnectedErrorDisplayed = false

Meteor.startup ->
  Deps.autorun ->
    status = Meteor.status()

    if status.connected
      count = Notify.documents.remove
        'sticky.disconnected':
          $exists: true
      disconnectedErrorDisplayed = false
      Notify.success "Connection to the server reestablished." if count

    else if status.status is 'connecting' and status.retryCount is 0 and not status.retryTime
      # Removing for every case
      Notify.documents.remove
        'sticky.disconnected':
          $exists: true
      disconnectedErrorDisplayed = false
      return # Establishing initial connection, we do not want a notification

    else if not disconnectedErrorDisplayed
      Notify.error "Connection to the server lost.", {template: 'connectionLost', data: status}, false, false, # Don't display the stack
        disconnected: true
      disconnectedErrorDisplayed = true

Template.connectionLost.events
  'click .connection-lost': (event, template) ->
    event.preventDefault()

    Meteor.reconnect()

    return # Make sure CoffeeScript does not return anything
