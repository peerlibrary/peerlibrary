$(document).ready(function(){

	//combine slide and fade toggle
	$.fn.slideFadeToggle  = function(speed, easing, callback) {
		return this.animate({opacity: 'toggle', height: 'toggle'}, speed, easing, callback);
	};

	$('.preview-link').click(function(){
		$(this).parent().parent().siblings('.abstract').slideFadeToggle();
	});

	//profile publications/reviews tab
	$('.publications-link').click(function(){
		$('.review-list').hide();
		$('.discussion').hide();
		$('.item-list').fadeIn(250);
		$('.publications-link').addClass('active');
		$('.reviews-link').removeClass('active');
		$('.full-text-link').removeClass('active');
		$('.discussion-link').removeClass('active');
	});

	$('.reviews-link').click(function(){
		$('.item-list').hide();
		$('.review-list').fadeIn(250);
		$('.discussion').hide();
		$('.publications-link').removeClass('active');
		$('.reviews-link').addClass('active');
		$('.full-text-link').removeClass('active');
		$('.discussion-link').removeClass('active');
	});

	$('.discussion-link').click(function(){
		$('.item-list').hide();
		$('.review-list').hide();
		$('.discussion').fadeIn(250);
		$('.publications-link').removeClass('active');
		$('.reviews-link').removeClass('active');
		$('.full-text-link').removeClass('active');
		$('.discussion-link').addClass('active');
	});
});