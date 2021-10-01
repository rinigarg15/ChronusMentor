/*
 *
 *   INSPINIA - Responsive Admin Theme
 *   version 2.3
 *
 */

 /*****************************************/
 /*****************************************/
 // VERY IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!
 /*****************************************/
 /*****************************************/
 // This file is modified and cannot 
 // be upgraded without checking the diff
 /*****************************************/

jQuery(document).ready(function () {

    // Add body-small class if window less than 768px
    if (jQuery(this).width() < 1200) {
        jQuery('body').addClass('body-small')
    } else {
        jQuery('body').removeClass('body-small')
    }

    // MetsiMenu
    jQuery('#side-menu').metisMenu();

    // Collapse ibox function
    jQuery(document).on('click', '.collapse-link', function() {
        closeIbox(this);
    });

    jQuery(document).on('click', '.ibox .cjs-cancel-ibox', function(){
        collapse_button = jQuery(this).parents(".ibox").find(".ibox-title .ibox-tools .collapse-link");
        closeIbox(collapse_button);
    });

    jQuery(document).on('click', '.ibox .ibox-title', function(event){
      var jTarget = jQuery(event.target);
      // Ignore if it is a collapse-link, or any anchor in ibox-title-content or any ibox-tools icon
      if(!jTarget.is('.collapse-link') && ((jTarget.is('a') && jTarget.closest('.ibox-title-content').length <= 0) || jTarget.closest('.ibox-title-content a, .ibox-tools').length <= 0)){
        // Ignore if ibox does not contain collapse-link
        collapse_button = jQuery(this).closest(".ibox").find(".ibox-title:first .ibox-tools .collapse-link:visible");
        if(collapse_button)
          collapse_button.click();
      }
    });

    // Close ibox function
    jQuery(document).on('click', '.close-link', function() {
        var content = jQuery(this).closest('div.ibox');
        content.remove();
    });

    // Fullscreen ibox function
    jQuery(document).on('click', '.fullscreen-link', function() {
        var ibox = jQuery(this).closest('div.ibox');
        // var iboxWrapper = jQuery("#" + ibox.attr("id") + "_fullscreen_wrapper");
        var button = jQuery(this).find('i');
        jQuery('body').toggleClass('fullscreen-ibox-mode');
        button.toggleClass('fa-expand').toggleClass('fa-compress');
        ibox.toggleClass('fullscreen');
        ibox.find(".cjs_hide_in_fullscreen").toggle();
        // if(jQuery('body').hasClass('fullscreen-ibox-mode')){
        //     jQuery('.wrapper').hide();
        //     jQuery('body').append(ibox[0].outerHTML);
        // }else{
        //     jQuery('.wrapper').show();
        //     iboxWrapper.html(ibox[0].outerHTML);
        // }
        // ibox.remove();
        setTimeout(function() {
            jQuery(window).trigger('resize');
        }, 100);
    });

    // Close menu in canvas mode
    jQuery('.close-canvas-menu').click( function() {
        jQuery("body").toggleClass("mini-navbar");
        SmoothlyMenu();
    });

    // Open close right sidebar
    jQuery('.right-sidebar-toggle').click(function(){
        jQuery('#right-sidebar').toggleClass('sidebar-open');
    });

    // Initialize slimscroll for right sidebar
    jQuery('.sidebar-container').slimScroll({
        height: '100%',
        railOpacity: 0.4,
        wheelStep: 10
    });

    // Open close small chat
    jQuery('.open-small-chat').click(function(){
        jQuery(this).children().toggleClass('fa-comments').toggleClass('fa-remove');
        jQuery('.small-chat-box').toggleClass('active');
    });

    // Initialize slimscroll for small chat
    jQuery('.small-chat-box .content').slimScroll({
        height: '234px',
        railOpacity: 0.4
    });

    // Small todo handler
    jQuery('.check-link').click( function(){
        var button = jQuery(this).find('i');
        var label = jQuery(this).next('span');
        button.toggleClass('fa-check-square').toggleClass('fa-square-o');
        label.toggleClass('todo-completed');
        return false;
    });

    function minimalizeMenuActions() {
        jQuery("body").toggleClass("mini-navbar");
        jQuery('.navbar-minimalize').find("span.hidden-lg i").toggleClass("animated rotateIn");
        SmoothlyMenu();
    }

    // Minimalize menu when tapped on the grey area when in tablet/phone
    jQuery("#content_wrapper").on("click", function(event) { 
        if(isMobileOrTablet() && jQuery("#content_wrapper").hasClass("cjs_hide_on_outside_click") && jQuery("body.body-small").hasClass("mini-navbar")){
            if(!jQuery(event.target).closest('#sidebarLeft').length && !jQuery(event.target).is('#sidebarLeft')) {
                if(jQuery('#sidebarLeft').is(":visible")) {
                    minimalizeMenuActions();
                }
            }
        }
    });

    // Minimalize menu
    jQuery('.navbar-minimalize').click(function () {
        minimalizeMenuActions();
        if(isMobileOrTablet()){
            if(jQuery("body.body-small").hasClass("mini-navbar")) {
                jQuery("#content_wrapper").addClass("cjs_hide_on_outside_click");
            }
            else {
                jQuery("#content_wrapper").removeClass("cjs_hide_on_outside_click");
            }
        }
    });


    // Tooltips demo
    jQuery('.tooltip-demo').tooltip({
        selector: "[data-toggle=tooltip]",
        container: "body",
        delay: { "show": 500, "hide": 100 }
    });

    // Move modal to body
    // Fix Bootstrap backdrop issu with animation.css
    jQuery('.modal').appendTo("body");

    // Full height of sidebar
    function fix_height() {
        var heightWithoutNavbar = jQuery("body > #wrapper").height() - 61;
        jQuery(".sidebard-panel").css("min-height", heightWithoutNavbar + "px");

        var navbarHeigh = jQuery('nav.navbar-default').height();
        var wrapperHeigh = jQuery('#page-wrapper').height();

        if(navbarHeigh > wrapperHeigh){
            jQuery('#page-wrapper').css("min-height", navbarHeigh + "px");
        }

        if(navbarHeigh < wrapperHeigh){
            jQuery('#page-wrapper').css("min-height", jQuery(window).height()  + "px");
        }

        if (jQuery('body').hasClass('fixed-nav')) {
            jQuery('#page-wrapper').css("min-height", jQuery(window).height() - 60 + "px");
        }

    }
    fix_height();

    // Fixed Sidebar
    jQuery(window).bind("load", function () {
        if (jQuery("body").hasClass('fixed-sidebar')) {
            jQuery('.sidebar-collapse').slimScroll({
                height: '100%',
                railOpacity: 0.9
            });
        }
    })

    // Move right sidebar top after scroll
    /*jQuery(window).scroll(function(){
        if (jQuery(window).scrollTop() > 0 && !jQuery('body').hasClass('fixed-nav') ) {
            jQuery('#right-sidebar').addClass('sidebar-top');
        } else {
            jQuery('#right-sidebar').removeClass('sidebar-top');
        }
    });*/

    jQuery(window).bind("load resize scroll", function() {
        if(!jQuery("body").hasClass('body-small')) {
            fix_height();
        }
    });

    jQuery("[data-toggle=popover]")
        .popover();

    // Add slimscroll to element
    jQuery('.full-height-scroll').slimscroll({
        height: '100%'
    })
});


// Minimalize menu when screen is less than 768px
jQuery(window).bind("resize", function () {
    if (jQuery(this).width() < 1200) {
        jQuery('body').addClass('body-small')
    } else {
        jQuery('body').removeClass('body-small')
    }
});

// Local Storage functions
// Set proper body class and plugins based on user configuration
jQuery(document).ready(function() {
    if (localStorageSupport) {

        var collapse = localStorage.getItem("collapse_menu");
        var fixedsidebar = localStorage.getItem("fixedsidebar");
        var fixednavbar = localStorage.getItem("fixednavbar");
        var boxedlayout = localStorage.getItem("boxedlayout");
        var fixedfooter = localStorage.getItem("fixedfooter");

        var body = jQuery('body');

        if (fixedsidebar == 'on') {
            body.addClass('fixed-sidebar');
            jQuery('.sidebar-collapse').slimScroll({
                height: '100%',
                railOpacity: 0.9
            });
        }

        if (collapse == 'on') {
            if(body.hasClass('fixed-sidebar')) {
                if(!body.hasClass('body-small')) {
                    body.addClass('mini-navbar');
                }
            } else {
                if(!body.hasClass('body-small')) {
                    body.addClass('mini-navbar');
                }

            }
        }

        if (fixednavbar == 'on') {
            jQuery(".navbar-static-top").removeClass('navbar-static-top').addClass('navbar-fixed-top');
            body.addClass('fixed-nav');
        }

        if (boxedlayout == 'on') {
            body.addClass('boxed-layout');
        }

        if (fixedfooter == 'on') {
            jQuery(".footer").addClass('fixed');
        }
    }
});

// check if browser support HTML5 local storage
function localStorageSupport() {
    return (('localStorage' in window) && window['localStorage'] !== null)
}

// For demo purpose - animation css script
function animationHover(element, animation){
    element = jQuery(element);
    element.hover(
        function() {
            element.addClass('animated ' + animation);
        },
        function(){
            //wait for animation to finish before removing classes
            window.setTimeout( function(){
                element.removeClass('animated ' + animation);
            }, 2000);
        });
}

function SmoothlyMenu() {
    if (!jQuery('body').hasClass('mini-navbar') || jQuery('body').hasClass('body-small')) {
        // Hide menu in order to smoothly turn on when maximize menu
        jQuery('#side-menu').hide();
        // For smoothly turn on menu
        setTimeout(
            function () {
                jQuery('#side-menu').fadeIn(500);
            }, 100);
    } else if (jQuery('body').hasClass('fixed-sidebar')) {
        jQuery('#side-menu').hide();
        setTimeout(
            function () {
                jQuery('#side-menu').fadeIn(500);
            }, 300);
    } else {
        // Remove all inline style from jquery fadeIn function to reset menu state
        jQuery('#side-menu').removeAttr('style');
    }
}

function closeIbox(button) {
  var ibox = jQuery(button).closest('div.ibox');
  var button = jQuery(button).find('i');
  var content = ibox.find('div.ibox-content');
  content.slideToggle(200);
  button.toggleClass('fa-chevron-up').toggleClass('fa-chevron-down');
  ibox.toggleClass('').toggleClass('border-bottom');
  setTimeout(function () {
      ibox.resize();
      ibox.find('[id^=map-]').resize();
  }, 50);
}

