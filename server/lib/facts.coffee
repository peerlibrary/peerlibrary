Facts.setUserIdFilter (userId) ->
  person = Person.documents.findOne
    'user._id': userId
  ,
    _id: 1
    isAdmin: 1

  person?.isAdmin
