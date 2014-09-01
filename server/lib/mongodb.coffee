MONGODB_INDEX_SORT_MAP =
  asc: 1
  desc: -1

@ensureCatalogSortIndexes = (documentClass) ->
  for sort in documentClass.PUBLISH_CATALOG_SORT
    indexSort = {}
    for field in sort.sort
      indexSort[field[0]] = MONGODB_INDEX_SORT_MAP[field[1]]
    documentClass.Meta.collection._ensureIndex indexSort
