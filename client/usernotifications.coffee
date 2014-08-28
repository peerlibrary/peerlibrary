# TODO: Replace with real logic
unseenNotifications = new Variable(2)

# We only allow the user notifications button to get wider during
# one session, so remember the widest it has been so far.
userNotificationsButtonCurrentMaxWidth = 0

Template.userNotificationsButton.rendered = ->
  # Only allow the user notifications button to get wider during one session,
  # by setting its mininmum width to the widest the button has been so far.
  $button = $(@find '.user-notifications-button')
  $button.css('min-width', userNotificationsButtonCurrentMaxWidth + "px");
  userNotificationsButtonCurrentMaxWidth = Math.max($button.width(), userNotificationsButtonCurrentMaxWidth)

Template.userNotificationsButton.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    $(template.findAll '.dropdown-anchor').show()

    unseenNotifications.set 0

    return # Make sure CoffeeScript does not return anything

Template.userNotificationsButtonContent.unseenCount = ->
  # TODO: Replace with real logic
  unseenNotifications()

# Set maximum height for the notifications dropdown dialog
resizeNotificationsDropdown = ->
  windowHeight = $(window).height()
  $('.user-notifications-menu .user-notifications').css 'max-height', windowHeight - 150

Template.userNotificationsDropdown.created = ->
  $(window).on 'resize.userNotifications', (event) =>
    resizeNotificationsDropdown()

Template.userNotificationsDropdown.rendered = ->
  resizeNotificationsDropdown()

Template.userNotificationsDropdown.destroyed = ->
  $(window).off '.userNotifications'

Template.userNotificationsDropdown.userNotifications = ->
  # TODO: Replace with real logic
  [
    icon: 'annotation'
    link: 'http://localhost:3000/p/7jaEmKsnkmwYHDJYJ/lattice-boltzmann-inverse-kinetic-approach-for-the-incompressible-navier-stokes/a/a7cYgkC8836rMRN2y'
    message: "New annotation on <span class='inline-item publication'><i class='icon-publication'></i>Lattice Boltzmann inverse kinetic approach for the incompressible Navier-Stokes equations</span>."
  ,
    icon: 'comment'
    link: 'http://localhost:3000/p/gXvMM3oC7F2QEkW5i/reality-of-linear-and-angular-momentum-expectation-values-in-bound-states/m/rRWNbbfoSrHfTXNTn'
    message: "New comment on <span class='inline-item annotation'><i class='icon-annotation'></i>a:ykBYQyGS6KiHYwQCk</span>"
  ,
    icon: 'group'
    link: 'http://localhost:3000/g/BYvKtx3JqAHYRpCBf/solid-state-physics-group'
    message: "3 new members have joined <span class='inline-item group'><i class='icon-group'></i>Solid State Physics Group</span>"
    read: true
  ,
    icon: 'highlight'
    link: 'http://localhost:3000/p/7jaEmKsnkmwYHDJYJ/lattice-boltzmann-inverse-kinetic-approach-for-the-incompressible-navier-stokes/a/a7cYgkC8836rMRN2y'
    message: "New annotation on <span class='inline-item publication'><i class='icon-publication'></i>Lattice Boltzmann inverse kinetic approach for the incompressible Navier-Stokes equations</span>."
    read: true
  ,
    icon: 'person'
    link: 'http://localhost:3000/p/gXvMM3oC7F2QEkW5i/reality-of-linear-and-angular-momentum-expectation-values-in-bound-states/m/rRWNbbfoSrHfTXNTn'
    message: "New comment on <span class='inline-item annotation'><i class='icon-annotation'></i>a:ykBYQyGS6KiHYwQCk</span>"
    read: true
  ,
    icon: 'publication'
    link: 'http://localhost:3000/g/BYvKtx3JqAHYRpCBf/solid-state-physics-group'
    message: "3 new members have joined <span class='inline-item group'><i class='icon-group'></i>Solid State Physics Group</span>"
    read: true
  ]

Template.userNotifications.userNotifications = Template.userNotificationsDropdown.userNotifications
