jQuery(document).on("click", '[data-toggle=offcanvas]', function(){
  jQuery('.row-offcanvas-left').toggleClass('active');
  jQuery('#offcanvasright').toggle();
});

jQuery(document).on("click", '[data-toggle=offcanvasright]', function(){
  if(jQuery(this).attr('id') == "cjs_user_filter") offCanvasHelper.userQuickFilter = true;
  offCanvasHelper.initiateToggle();
});

var offCanvasHelper = {
  userQuickFilter: false,

  handleCloseLink: function(){
    if(sidePaneOpened && jQuery(".close-link").is(":visible")) {
      jQuery('#SidebarRightContentMobile').html("");
      jQuery('#SidebarRightContainer').show();
    }
  },

  initiateToggle: function(){
    offCanvasHelper.handleCloseLink();
    if(jQuery('[data-toggle=offcanvasright] i#cjs-chevron-header').hasClass('fa-chevron-left'))
    {
      jQuery('.mobile_footer').show();
      sidePaneOpened = false;
      if(window.location.hash.indexOf(jQuery('#SidebarRightHomeContent').attr('id')) != -1  && !offCanvasHelper.userQuickFilter){
        window.history.back(); //Just removes the hash #SidebarRightHomeContent from the URL
      }
    }
    offCanvasHelper.toggleRightCanvas();
  },

  toggleRightCanvas: function(){
    if ((jQuery('body').hasClass('mini-navbar') && jQuery('body').hasClass('body-small')) || !jQuery('body').hasClass('mini-navbar')) {
      jQuery('#mobile_header_wrapper .navbar-minimalize').trigger('click');
    }
    jQuery('.row-offcanvas-right').toggleClass('active');
    if(jQuery('[data-toggle=offcanvasright] i#cjs-chevron-header').hasClass('fa-chevron-right') && jQuery('#SidebarRightContentMobile').is(":visible"))
    {
      jQuery('.mobile_footer').hide();
      sidePaneOpened = true;
      if(window.location.hash.indexOf("#SidebarRightHomeContent") == -1)
        window.location.hash += jQuery('#SidebarRightHomeContent').attr('id');
    }
    jQuery('#offcanvasleft').toggle();
    jQuery('[data-toggle=offcanvasright] i#cjs-chevron-header').toggleClass('fa-chevron-right fa-chevron-left');
    jQuery('#cjs_sidebar_footer').toggle();
    jQuery('body').toggleClass("cui_offcanvas_open");
    //scroll to actionable widgets if present
    if(jQuery('#cjs_connections_widget').is(":visible")){
      jQueryScrollTo("#cjs_connections_widget", false, 50);
    }
    else if(jQuery('#cjs_flash_meetings_widget').is(":visible")){
      jQueryScrollTo("#cjs_flash_meetings_widget", false, 50);
    }
  }
}