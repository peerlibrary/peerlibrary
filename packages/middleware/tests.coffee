USERS_COLLECTION = 'Users_meteor_middleware_tests'

Users = new Meteor.Collection USERS_COLLECTION
LogActions = new Meteor.Collection 'LogActionsActions_meteor_middleware_tests'

Error.stackTraceLimit = Infinity;

if Meteor.isServer
  # Initialize the database
  Meteor.methods
    'initialize-database': ->
      Users.remove {}
      LogActions.remove {}

  Meteor.call 'initialize-database'

  allUsers = new PublishEndpoint 'all-users', (argument1, argument2) ->
    assert _.isEqual @params(), [argument1, argument2]
    assert.equal argument1, 'first'
    assert.equal argument2, 'second'

    Users.find()

  new PublishEndpoint null, ->
    LogActions.find()

  class TestMiddleware extends PublishMiddleware
    constructor: (@name) ->
      super

    added: (publish, collection, id, fields) =>
      assert.equal publish.params().length, 2

      LogActions.insert
        name: @name,
        type: 'added'
        args: [collection, id, fields]

      super

    changed: (publish, collection, id, fields) =>
      assert.equal publish.params().length, 2

      LogActions.insert
        name: @name,
        type: 'changed'
        args: [collection, id, fields]

      super

    removed: (publish, collection, id) =>
      assert.equal publish.params().length, 2

      LogActions.insert
        name: @name,
        type: 'removed'
        args: [collection, id]

      super

    onReady: (publish) =>
      assert.equal publish.params().length, 2

      LogActions.insert
        name: @name,
        type: 'onReady'
        args: []

      super

    onStop: (publish) =>
      assert.equal publish.params().length, 2

      LogActions.insert
        name: @name,
        type: 'onStop'
        args: []

      super

    onError: (publish, error) =>
      # Here we only check if params exists, but not really
      # the content, so that the error can propagate.
      assert publish.params

      LogActions.insert
        name: @name,
        type: 'error'
        args: [error]

      super

  class HasPostsMiddleware extends PublishMiddleware
    added: (publish, collection, id, fields) =>
      fields.hasPosts = !!fields.posts
      super publish, collection, id, fields

    changed: (publish, collection, id, fields) =>
      if 'posts' of fields
        fields.hasPosts = !!fields.posts
      super publish, collection, id, fields

  allUsers.use new TestMiddleware 'first'
  allUsers.use new HasPostsMiddleware()
  allUsers.use new TestMiddleware 'last'

if Meteor.isClient
  testAsyncMulti 'middleware - basic', [
    (test, expect) ->
      Meteor.call 'initialize-database', expect (error) ->
        test.isFalse error
  ,
    (test, expect) ->
      # Let's wait a bit for log to be cleared from the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      test.equal Users.find().count(), 0
      test.equal LogActions.find().count(), 0

      @log = []

      @subscribe = Meteor.subscribe 'all-users', 'first', 'second',
        onReady: expect()
        onError: (error) ->
          test.exception error
  ,
    (test, expect) ->
      # Let's wait a bit for log to be pushed to the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      test.equal Users.find().fetch(), []

      @log.push
        name: 'first'
        type: 'onReady'
        args: []
      ,
        name: 'last'
        type: 'onReady'
        args: []

      test.equal (_.omit(obj, '_id') for obj in LogActions.find().fetch()), @log

      @users = []

      for i in [0...10]
        Users.insert {}, expect (error, id) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue id
          @users.push id

          @log.push
            name: 'first'
            type: 'added'
            args: [USERS_COLLECTION, id, {}]
          ,
            name: 'last'
            type: 'added'
            args: [USERS_COLLECTION, id, {hasPosts: false}]
  ,
    (test, expect) ->
      # Let's wait a bit for log to be pushed to the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      test.equal Users.find().fetch(), ({_id: id, hasPosts: false} for id in @users)

      test.equal (_.omit(obj, '_id') for obj in LogActions.find().fetch()), @log

      Users.update @users[0],
        $set:
          posts: ['foobar']
      ,
        expect (error, count) =>
          test.isFalse error
          test.equal count, 1

          @log.push
            name: 'first'
            type: 'changed'
            args: [USERS_COLLECTION, @users[0], {posts: ['foobar']}]
          ,
            name: 'last'
            type: 'changed'
            args: [USERS_COLLECTION, @users[0], {hasPosts: true, posts: ['foobar']}]
  ,
    (test, expect) ->
      # Let's wait a bit for log to be pushed to the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      users = ({_id: id, hasPosts: false} for id in @users)
      users[0].hasPosts = true
      users[0].posts = ['foobar']

      test.equal Users.find().fetch(), users

      test.equal (_.omit(obj, '_id') for obj in LogActions.find().fetch()), @log

      @subscribe.stop()
  ,
    (test, expect) ->
      expectFunction = expect()
      Meteor.subscribe 'all-users', 'a', 'b',
        onReady: =>
          test.fail
            type: 'assert_not_expecting'
          expectFunction()
        onError: (error) =>
          test.isTrue error
          expectFunction()

          @log.push
            name: 'first'
            type: 'error'
            args: [
              actual: 'a'
              expected: 'first'
              message: '"a" == "first"'
              name: 'AssertionError'
              operator: '=='
            ]
          ,
            name: 'last'
            type: 'error'
            args: [
              actual: 'a'
              expected: 'first'
              message: '"a" == "first"'
              name: 'AssertionError'
              operator: '=='
            ]
  ,
    (test, expect) ->
      # Let's wait a bit for log to be pushed to the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      test.equal (_.omit(obj, '_id') for obj in LogActions.find().fetch()), @log

      expectFunction = expect()
      Meteor.subscribe 'all-users',
        onReady: =>
          test.fail
            type: 'assert_not_expecting'
          expectFunction()
        onError: (error) =>
          test.isTrue error
          expectFunction()

          @log.push
            name: 'first'
            type: 'error'
            args: [
              actual: false
              expected: true
              message: 'false == true'
              name: 'AssertionError'
              operator: '=='
            ]
          ,
            name: 'last'
            type: 'error'
            args: [
              actual: false
              expected: true
              message: 'false == true'
              name: 'AssertionError'
              operator: '=='
            ]
  ,
    (test, expect) ->
      # Let's wait a bit for log to be pushed to the client
      Meteor.setTimeout expect(), 100
  ,
    (test, expect) ->
      test.equal (_.omit(obj, '_id') for obj in LogActions.find().fetch()), @log
  ]
