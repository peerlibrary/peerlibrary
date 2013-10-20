# We are redefining documents on client and server, so we have to update metadata with new
# document defintions. This takes care of possible recursive references as well. For this
# to work, all metadata should be provided as functions and not directly.

Document.redefineAll()