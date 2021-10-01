(function($){
	$.fn.scrollelement = function(options) {
		var defaults = { 
			'animate': false,
			'duration': 'fast',
			'easing': 'linear',
			'complete': function(){},
			'offset': 0
		};
		
		var options = $.extend(defaults, options);
		
		return this.each(function() {
			var element = $(this);
			var offset = element.offset().top - options.offset;
			var toScroll = 0;
			
			$(window).scroll(function(){ 
				var scroll = $(window).scrollTop();
				if( scroll > offset ){
					toScroll = scroll - offset;
				} else {
					toScroll = 0;
				}
				
				if( options.animate == true ){
					element.stop().animate({"margin-top": toScroll + "px"}, options.duration, options.easing, options.complete );
				} else {
					element.stop().css("margin-top", toScroll + "px");
				}
			});
			
		});
	}
})(jQuery)