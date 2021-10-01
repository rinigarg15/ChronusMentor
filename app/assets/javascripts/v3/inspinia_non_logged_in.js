// INSPINIA Landing Page Custom scripts
jQuery(document).ready(function () {

    // Highlight the top nav as scrolling
    jQuery('body').scrollspy({
        target: '.navbar-fixed-top',
        offset: 80
    })

    // Page scrolling feature
    jQuery('a.page-scroll').bind('click', function(event) {
        var link = jQuery(this);
        jQuery('html, body').stop().animate({
            scrollTop: jQuery(link.attr('href')).offset().top - 70
        }, 500);
        event.preventDefault();
    });

});

// Activate WOW.js plugin for animation on scrol
// new WOW().init();
