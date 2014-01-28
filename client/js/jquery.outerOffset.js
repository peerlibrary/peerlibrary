// jQuery offset() returns coordinates of the content part of the element,
// ignoring any margins. outerOffet() returns outside coordinates of the
// element, including margins.

$.fn.outerOffset = function () {
    var $this = $(this);
    var marginLeft = parseFloat($this.css('margin-left'));
    var marginTop = parseFloat($this.css('margin-top'));
    var offset = $this.offset();
    offset.left -= marginLeft;
    offset.top -= marginTop;
    return offset;
};
