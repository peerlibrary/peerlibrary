# Allow easy access to a template instance field when you do not know exactly
# on which instance (this, or parent, or parent's parent, ...) a field is defined.
# This allows easy restructuring of templates in HTML, moving things to included
# templates without having to change everywhere in the code instance levels.
# It also allows different structures of templates, when once template is included
# at one level, and some other time at another. Levels do not matter anymore, just
# that the field exists somewhere.
Blaze.TemplateInstance::get = (fieldName) ->
  template = @

  while template
    if fieldName of template
      return template[fieldName]

    template = template.parent 1

  return
