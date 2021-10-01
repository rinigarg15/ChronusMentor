(function($) {
    $.extend({
        add2cart: function(source_id, target_id, options) {
            var source = $('#' + source_id);
            var target = $('#' + target_id);
            var defaults = {
                opacity: 0.5,
                width: '10px',
                height: '10px',
                duration: 1250,
				callback: function() {}
            };
            var opts = $.extend(defaults, options);
            var display = $('#' + source_id).clone();
			display.css('margin','0').css('border-width','0');
            var display_image = $('<div>').append(display).remove().html();

            var shadow = $('#' + source_id + '_shadow');
            if (!shadow.attr('id')) {
                $('body').prepend('<div id="' + source.attr('id') + '_shadow" style="float:left; border: solid 1px #777; position: static;top:0px; left: 0px;z-index:100000;">' + display_image + '</div>');
                shadow = $('#' + source.attr('id') + '_shadow');
            }

            if (!shadow) {
                alert('Cannot create the shadow div');
            }

            shadow.css('position', 'absolute');
            shadow.width(source.css('width')).height(source.css('height')).css('top', source.offset().top).css('left', source.offset().left).css('opacity', opts.opacity).css('filter', 'alpha(opacity='+opts.opacity*100+')').show();


            shadow.animate(
            {
                top: target.offset().top,
                left: target.offset().left,
                width: opts.width,
                height: opts.height
            },	
			{
	            duration: opts.duration,
	            specialEasing: {
	               width: 'linear',
	               height: 'linear'
	            }
	        },
            function() {
                shadow.hide();
            	
			}).animate({
                opacity: 0
            },
            0,
            function() {
                shadow.remove();
				opts.callback();
            });
        }
    });
})(jQuery);