// Based on Interface Query (iQuery), jQuery plugin, v1.1
// http://e-infotainment.com/projects/interface-query/

(function ($) {
    $.fn.forwardMouseEvents = function () {
        // Assure we are processing one element at the time
        this.each(function (i, el) {
            var $this = $(this),
                $lastT = null;

            function trigger($elem, eventType, event, relatedTarget) {
                // We do not want to forward an event which has been marked to not be propagated
                if (event.isPropagationStopped() || event.isImmediatePropagationStopped())
                    return;

                var originalType = event.type,
                    originalEvent = event.originalEvent,
                    originalTarget = event.target,
                    originalRelatedTarget = event.relatedTarget;

                var $commonAncestor = $this.parents().has($elem).first();

                try {
                    event.target = $elem[0];
                    event.type = eventType;
                    event.originalEvent = null;
                    event.forwardedEvent = true;

                    if (relatedTarget)
                        event.relatedTarget = relatedTarget;

                    if ($commonAncestor.length) {
                        var eventName = eventType + '.forwarding';
                        // Install the event handler on the common ancestor and prevent forwarded
                        // events from propagating further (original event propagates on that path already)
                        // Use jQuery.bind-first's onFirst to assure we are first handler to be
                        // called on common ancestor to be able to prevent immediate propagation
                        // completly (original event propagates on common ancestor itself as well)
                        $commonAncestor.off(eventName).onFirst(eventName, function (e) {
                            if (e.forwardedEvent) {
                                e.stopImmediatePropagation();
                            }
                        })
                    }

                    $elem.trigger(event);
                }
                finally {
                    event.type = originalType;
                    event.originalEvent = originalEvent;
                    event.target = originalTarget;
                    event.relatedTarget = originalRelatedTarget;
                    delete event.forwardedEvent;
                }
            }

            $this.on('mouseleave', function (e) {
                if ($lastT && e.relatedTarget !== $lastT[0]) {
                    trigger($lastT, 'mouseout', e, e.relatedTarget);
                    $lastT = null;
                }
            }).on('mousemove mousedown mouseup mousewheel click dblclick', function (e) {
                // Assumption, event should already be made by a browser on underlying elements if $this is not visible
                // And we hide and show $this below, so we do not want it to appear if hidden initially
                if (!$this.is(':visible'))
                    return;

                var be = e.originalEvent,
                    et = be.type,
                    mx = be.clientX,
                    my = be.clientY,
                    $t;

                $this.hide();
                $t = $(document.elementFromPoint(mx, my));
                $this.show();

                if (!$t) {
                    if ($lastT) {
                        trigger($lastT, 'mouseout', e);
                        $lastT = null;
                    }
                    return;
                }

                trigger($t, et, e);

                if (!$lastT || $t[0] !== $lastT[0]) {
                    if ($lastT) {
                        trigger($lastT, 'mouseout', e, $t[0]);
                    }
                    trigger($t, 'mouseover', e, $lastT ? $lastT[0] : $this[0]);
                }
                $lastT = $t;
            });
        });

        // For chaining
        return this;
    };
})(jQuery);
