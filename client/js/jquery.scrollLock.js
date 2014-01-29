// Based on https://stackoverflow.com/questions/5802467/prevent-scrolling-of-parent-element

$.fn.scrollLock = function () {
    return $(this).on('mousewheel', function (e) {
        var $this = $(this);
        var scrollTop = $this.scrollTop();
        var scrollHeight = this.scrollHeight;
        var height = $this.height();
        var up = e.deltaY > 0;

        // If there is no scroller, don't do anything
        if (scrollHeight === height) return;

        if (!up && -e.deltaY > scrollHeight - height - scrollTop) {
            // Scrolling down, but this will take us past the bottom
            $this.scrollTop(scrollHeight - height);
            e.stopPropagation();
            e.preventDefault();
        }
        else if (up && e.deltaY > scrollTop) {
            // Scrolling up, but this will take us past the top
            $this.scrollTop(0);
            e.stopPropagation();
            e.preventDefault();
        }
    });
};
