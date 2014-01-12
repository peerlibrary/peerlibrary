// Based on Interface Query (iQuery), jQuery plugin, v1.1
// http://e-infotainment.com/projects/interface-query/

(function ($) {
    function trigger($elem, eventType, event, relatedTarget) {
        // TODO: Instead of using forwardedEvent, we should see if $elem has any common parent with $this and prevent propagation from that parent on, so that the event would not bubble twice from the common parent on
        // TODO: Don't propagate if prevent propagation was set to true

        var originalType = event.type,
            originalEvent = event.originalEvent,
            originalTarget = event.target,
            originalRelatedTarget = event.relatedTarget;

        try {
            event.target = $elem[0];
            event.type = eventType;
            event.originalEvent = null;
            event.forwardedEvent = true;

            if (relatedTarget)
                event.relatedTarget = relatedTarget;

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

    $.fn.forwardMouseEvents = function () {
        var $this = this,
            $lastT = null;

        $this.on('mouseleave', function (e) {
            if ($lastT && e.relatedTarget !== $lastT[0]) {
                trigger($lastT, 'mouseout', e, e.relatedTarget);
                $lastT = null;
            }
        }).on('mousemove mousedown mouseup mousewheel click dblclick', function (e) {
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

        return $this;
    };
})(jQuery);
