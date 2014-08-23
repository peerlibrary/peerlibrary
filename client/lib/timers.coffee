class @PausableTimeout
  constructor: (func, @delay) ->
    @func = _.bind(func, null)
    @done = false
    @timeoutId = null
    @start = null
    @remaining = @delay

    @resume()

  isResumable: =>
    not @done and not @timeoutId

  resume: =>
    return unless @isResumable()

    @start = moment.utc().valueOf()
    @timeoutId = Meteor.setTimeout @_run, @remaining

    # We return remaining
    @remaining

  isPausable: =>
    !!@timeoutId

  pause: =>
    return unless @isPausable()

    Meteor.clearTimeout @timeoutId
    @timeoutId = null

    # To guard against overflows and time jumps
    @remaining = Math.max(0, Math.min(@remaining - (moment.utc().valueOf() - @start), @delay))

    # We return remaining

  _run: =>
    @done = true
    @timeoutId = null
    @func()

visibleTimeoutLastId = 0
visibleTimeouts = {}

class @VisibleTimeout extends @PausableTimeout
  constructor: ->
    @id = visibleTimeoutLastId++

    super

  resume: =>
    return unless @isResumable()

    visibleTimeouts[@id] = @

    super

  pause: =>
    return unless @isPausable()

    delete visibleTimeouts[@id]

    super

  _run: =>
    delete visibleTimeouts[@id]

    super

Meteor.startup ->
  pausedTimeouts = []

  Visibility.change (event, state) ->
    if state is 'hidden'
      pausedTimeouts = _.values visibleTimeouts
      timeout.pause() for timeout in pausedTimeouts
    else
      timeout.resume() for timeout in pausedTimeouts
      pausedTimeouts = []
