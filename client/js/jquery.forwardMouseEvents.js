// Based on Interface Query (iQuery), jQuery plugin, v1.1
// http://e-infotainment.com/projects/interface-query/

(function ($) {
    var globalId = 1;

    $.fn.forwardMouseEvents = function () {
        // Assure we are processing one element at the time
        this.each(function (i, el) {
            var localId = globalId++,
                $this = $(this),
                $lastT = null;

            function trigger($elementsAbove, $elem, eventType, event, relatedTarget) {
                // We do not want to forward an event which has been marked to not be forwarded or propagated
                if ((event.isForwardingStopped && event.isForwardingStopped()) || event.isPropagationStopped() || event.isImmediatePropagationStopped())
                    return;

                var newEvent = $.extend({}, event, {
                    'target': $elem[0],
                    'type': eventType,
                    'originalEvent': null,
                    'forwardedEventId': localId,
                    'elementsAbove': $elementsAbove,
                    'forwardingStopped': false,
                    'isForwardingStopped': function () {
                        return newEvent.forwardingStopped;
                    },
                    'stopForwarding': function () {
                        newEvent.forwardingStopped = true;
                    }
                });

                if (relatedTarget)
                    newEvent.relatedTarget = relatedTarget;
                else if (newEvent.relatedTarget)
                    delete newEvent.relatedTarget;

                var $commonAncestor = $();
                $elementsAbove.each(function (i, el) {
                    $commonAncestor = $commonAncestor.add($(el).parents().has($elem).first());
                });

                if ($commonAncestor.length) {
                    var eventName = eventType + '.forwarding-' + localId;
                    // Install the event handler on the common ancestor and prevent forwarded
                    // events from propagating further (original event propagates on that path already)
                    // Use jQuery.bind-first's onFirst to assure we are first handler to be
                    // called on common ancestor to be able to prevent immediate propagation
                    // completely (original event propagates on common ancestor itself as well)
                    $commonAncestor.off(eventName).onFirst(eventName, function (e) {
                        if (e.forwardedEventId === localId) {
                            e.stopImmediatePropagation();
                        }
                    })
                }

                $elem.trigger(newEvent);
            }

            $this.on('mouseleave', function (e) {
                if ($lastT && e.relatedTarget !== $lastT[0]) {
                    trigger($(), $lastT, 'mouseout', e, e.relatedTarget);
                    $lastT = null;
                }
            }).on('mousemove mousedown mouseup mousewheel click dblclick', function (e) {
                // Assumption, event should already be made by a browser on underlying elements if $this is not visible
                // And we hide and show $this below, so we do not want it to appear if hidden initially
                if (!$this.is(':visible'))
                    return;

                // Workaround for a bug in Chrome which retriggers mousemove because of the document.elementFromPoint call below
                // See http://code.google.com/p/chromium/issues/detail?id=333623
                if (e.type === 'mousemove' && e.originalEvent && e.originalEvent.webkitMovementX === 0 && e.originalEvent.webkitMovementY === 0)
                    return;

                var et = e.type,
                    mx = e.clientX,
                    my = e.clientY,
                    $ea = e.elementsAbove || $(),
                    $t;

                $ea = $ea.add($this);

                $ea.hide();
                $t = $(document.elementFromPoint(mx, my));
                $ea.show();

                if (!$t) {
                    if ($lastT) {
                        trigger($ea, $lastT, 'mouseout', e);
                        $lastT = null;
                    }
                    return;
                }

                trigger($ea, $t, et, e);

                if (!$lastT || $t[0] !== $lastT[0]) {
                    if ($lastT) {
                        trigger($ea, $lastT, 'mouseout', e, $t[0]);
                    }
                    trigger($ea, $t, 'mouseover', e, $lastT ? $lastT[0] : $this[0]);
                }
                $lastT = $t;
            });
        });

        // For chaining
        return this;
    };
})(jQuery);
