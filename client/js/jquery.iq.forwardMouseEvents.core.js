(function ($) {

    function trigger($elem, eventType, event, relatedTarget) {
        var originalType = event.type,
			originalEvent = event.originalEvent,
			originalTarget = event.target,
			originalRelatedTarget = event.relatedTarget;

        event.target = $elem[0];
        event.type = eventType;
        event.originalEvent = null;

        if (relatedTarget)
            event.relatedTarget = relatedTarget;

        $elem.trigger(event);

        event.type = originalType;
        event.originalEvent = originalEvent;
        event.target = originalTarget;
        event.relatedTarget = originalRelatedTarget;
    }

    $.iq.plugin("forwardMouseEvents", {
        options: {
            enableMousemove: false,
            dblClickThreshold: 500
        },
        //_suspended: false,        
        _init: function () {
            var instance = this,
                options = instance.options,
				$this = instance.element,
                xy, lastT,
				clickX, clickY,
                clicks = 0,
                lastClick = 0;

            $this.bind('mouseout', function (e) {
                if (lastT) {
                    trigger(lastT, 'mouseout', e, $this[0]);
                    //lastT = null;
                }
            }).bind('mousemove mousedown mouseup mousewheel', function (e) {

                //if (!instance._suspended)
                if (options.enabled && $this.is(':visible')) {

                    //instance._suspended = true;

                    var be = e.originalEvent,
                        et = be.type,
                        mx = be.clientX,
                        my = be.clientY,
                        t;

                    e.stopPropagation();
                    $this.hide();
                    t = $(document.elementFromPoint(mx, my));                    
                    $this.show();
					console.log(lastT);
					
                    if (!t) {
                        trigger(lastT, 'mouseout', e);
                        lastT = t;						
                        //instance._suspended = false;
                        return;
                    }

                    if (options.enableMousemove || et !== 'mousemove') {
                        trigger(t, et, e);
                    }
					
                    if (lastT && (t[0] === lastT[0])) {	
						if (et == 'mouseup') {

                            // using document.elementFromPoint in mouseup doesn't trigger dblclick event on the overlay
                            // hence we have to manually check for dblclick
                            if (clickX != mx || clickY != my || (e.timeStamp - lastClick) > options.dblClickThreshold) {
                                clicks = 0;
                            }

                            clickX = mx;
                            clickY = my;
                            lastClick = e.timeStamp;
                            trigger(t, 'click', e);

                            if (++clicks == 2) {
                                trigger(t, 'dblclick', e);
                                clicks = 0;
                            }
                        }
                    } else {
						
						clicks = 0;
                        if (lastT) {		
							trigger(lastT, 'mouseout', e, t[0]);
                        }
						trigger(t, 'mouseover', e, lastT ? lastT[0] : $this[0]);
                    }
					lastT = t;
                    //instance._suspended = false;
                }
            });
        }
    });

})(jQuery);
