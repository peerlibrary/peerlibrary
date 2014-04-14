# Reactive variable which is updated only if keys of a value are changed
class @KeysEqualityVariable extends Variable
  equals: (a, b) ->
    assert _.isObject a
    assert _.isObject b

    a = _.keys a
    b = _.keys b
    a.length is b.length and _.difference(a, b).length is 0
