MainView = Backbone.View.extend
  id: 'main-view'
  className: 'container'
  
  events:
    'click h1': 'loadTime'
    
  initialize: ->
    @loadTime()
  
  render: ->
    Meteor.render ->
      Template.hello
        person: "Rodrigo"
        time: Session.get('time')
    
  loadTime: ->
    Meteor.call 'server-time', (err, time) ->
      Session.set 'time', time


AppRouter = Backbone.Router.extend
  routes:
    "": "main"

  main:  ->
    $('body').append (new MainView).render()

Router = new AppRouter

Meteor.startup ->  
  Backbone.history.start pushState: true  