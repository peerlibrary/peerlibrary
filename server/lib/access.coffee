@requireReadAccess = (person, selector) ->
  return selector if person?.isAdmin

  # We use $or inside of $and to not override any existing $or
  selector.$and = [] unless selector.$and
  selector.$and.push
    $or: [
      access: ACCESS.PUBLIC
    ,
      access: ACCESS.PRIVATE
      'readUsers._id': person?._id
    ,
      access: ACCESS.PRIVATE
      'readGroups._id':
        $in: _.pluck person?.inGroups, '_id'
    ]
  selector
