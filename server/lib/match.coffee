@PositiveNumber = Match.Where (x) ->
  check x, Number
  x > 0