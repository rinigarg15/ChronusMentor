var FeatureMobile = {
  verifyOrganization: function(cookieName, options) {
    jQuery(".cjs_verify_org").submit(function() {
      var url = jQuery(this).find(".cjs_verify_org_name").val();
      return FeatureMobile.handleUrlLoad(url, cookieName, options);
    });
  },

  handleUrlLoad: function(url, cookieName, options){
    if(url.blank()) {
      ChronusValidator.ErrorManager.ShowResponseFlash("verify_organization", options.emptyErrorMessage, false);
    }
    else {
      // Users sometimes enter 'http://chronus.com' - strip the protocol as we are manually adding http in next line
      if (options.eventLabel != ""){
        MobileAppTracking.gaTrackEnteredProgramUrl(options.eventLabel, options.eventLabelId);
      }
      url = FeatureMobile.getFormattedUrl(url);
      var dummyAnchor = ProgramUrlHelper.createAnchor(url);

      var organizationUrlWithProtocol = ProgramUrlHelper.getOrganizationUrlWithProtocol(dummyAnchor, options);
      var programUrlWithProtocol = organizationUrlWithProtocol + ProgramUrlHelper.getProgramRootPath(dummyAnchor);
      var validateOrganizationPath = programUrlWithProtocol + options.validatePath;
      if (options.port != ""){
        dummyAnchor.port = options.port;
      }
      var completeUrl = dummyAnchor.href;
      jQuery.ajax({
        url: validateOrganizationPath,
        dataType: 'json',
        timeout: parseInt(options.verifyOrgTimeOut),
        beforeSend: function(){
          HybridNav.resetDefaultHostChr();
          var spinnerOptions = { dimBackground: false };
          SpinnerPlugin.activityStart('', spinnerOptions);
        },
        success: function(response){
          if(response.status === "ok") {
            SpinnerPlugin.activityStop();
            cordovaNetworkHelper.setDefaultHosts(response.default_hosts);
            //Set organization url cookie and redirect
            jQuery.cookie(cookieName, response.valid_program ? programUrlWithProtocol : organizationUrlWithProtocol, { expires: parseInt(options.cookieExpiry), path: '/' });

            var newLocation = (response.valid_program ? completeUrl : completeUrl.split('/')[3] == "p" ? organizationUrlWithProtocol : completeUrl);
            newLocation = newLocation.replace(/\/$/, "");
            //removing protocol and checking if we need to redirect to login page
            newLocation = newLocation + (programUrlWithProtocol == FeatureMobile.getFormattedUrl(newLocation) ? options.mobileLoginPath : "");
            newLocation = FeatureMobile.updateQueryString("cjs_from_select_org", "true", newLocation);
            newLocation = FeatureMobile.updateQueryString("uniq_token", options.uniq_token, newLocation);
            window.location.href = newLocation;
          }
          else {
            FeatureMobile.handleInvalidOrg(options.invalidErrorMessage);
          }
        },
        error: function(XMLHttpRequest, textStatus, errorThrown) {
          FeatureMobile.handleInvalidOrg(options.invalidErrorMessage);
        }
      });
    }
      return false;
  },

  handleInvalidOrg: function(invalidErrorMessage){
    HybridNav.resetDefaultHostChr();
    SpinnerPlugin.activityStop();
    ChronusValidator.ErrorManager.ShowResponseFlash("verify_organization", invalidErrorMessage, false);
    jQuery(".cjs_verify_org_name").val("");
  },

  verifyEmail: function(options){
    jQuery(".cjs_verify_email_address").submit(function() {
      var email = jQuery(this).find(".cjs_verify_email_address_email").val();
      var isEmailFormatValid = verifyEmailFormat(email);
      if(email.blank()) {
        ChronusValidator.ErrorManager.ShowResponseFlash("verify_email_address", options.emptyErrorMessage, false);
      }
      else if(!isEmailFormatValid){
        ChronusValidator.ErrorManager.ShowResponseFlash("verify_email_address", options.invalidErrorMessage, false);
      }
      else{
        FeatureMobile.handleEmailVerification(email, options);
      }
      return false;
    });
  },

  handleEmailVerification: function(email, options){
    MobileAppTracking.gaTrackEnteredEmailAddress(options.eventLabel, options.eventLabelId);
    jQuery.ajax({
      url: options.validatePath,
      type: "POST",
      data: {email: email},
      dataType: 'json',
      beforeSend: function(){
        var spinnerOptions = { dimBackground: false };
        SpinnerPlugin.activityStart('', spinnerOptions);
      },
      complete: function(){
        SpinnerPlugin.activityStop();
        jQuery(".cjs_verify_email_address_email").val("");
        ChronusValidator.ErrorManager.ShowPageFlash(true, options.successMessage + " " + email + ".", "", true);;  
      }
    });
  },

  handleInvalidEmailAddress: function(invalidErrorMessage){
    SpinnerPlugin.activityStop();
    ChronusValidator.ErrorManager.ShowResponseFlash("verify_email_address", invalidErrorMessage, false);
    jQuery(".cjs_verify_email_address_email").val("");
  },

  initializeOpenurl: function(redirect_url, cookieName, options){
    document.addEventListener("deviceready", function(){
      FeatureMobile.handleUrlLoad(redirect_url, cookieName, options);
    });
  },

  getFormattedUrl: function(url){
    url = url.replace(/^http[s]?:\/\//i, "").replace(/www./i, "").replace("\/\/", "");
    url = "//" + url;
    return url;
  },

  initializeLanguageDropdown: function(){
    jQuery("#statusbar_header li.mobile_dropdown").click(function(){
      jQuery(this).children(".dropdown-menu").toggle();
      jQuery(this).children(".dropdown-toggle").addClass('active');
    });
    jQuery(document).on("click", function(event){
      var dropdown = jQuery("#statusbar_header li.mobile_dropdown");
      if(dropdown !== event.target && !dropdown.has(event.target).length){
        dropdown.children(".dropdown-menu").hide();
        dropdown.children(".dropdown-toggle").removeClass('active');
      }            
    });
  },

  initializeGaForFakedoorAndBackLinkAndProgramForms: function(eventLabel, eventLabelId, page_header_text){
    var clone = jQuery(".cjs_chronus_logo_mobile").clone();
    jQuery(document).on("click", ".cjs_fakedoor_link", function(){
      MobileAppTracking.gaTrackClickedFakedoorLink(eventLabel, eventLabelId);
    });

    jQuery(document).on("click", ".cjs_enter_program_url_link", function(){
      FeatureMobile.setFormAndHeaderForProgramForm(page_header_text);
      MobileAppTracking.gaTrackClickedEnterProgramURL(eventLabel, eventLabelId);
    });

    jQuery(document).on("click", ".cjs_signup_link", function(){
      FeatureMobile.setFormAndHeaderForProgramForm(page_header_text);
      MobileAppTracking.gaTrackClickedSignUp(eventLabel, eventLabelId);
    });

    jQuery(document).on("click", ".cjs_mobile_email_address_back_link", function(){
      jQuery(".cui-homepage-ibox").addClass("cui-homepage");
      jQuery(".cjs_verify_org").hide();
      jQuery(".cjs_verify_email_address").show();
      jQuery(".cjs_mobile_email_address_back_link").replaceWith(clone);
      jQuery("#mobile_header_links").show();
      jQuery(".cjs_statusbar_header_theme_div").removeClass("col-xs-12").addClass("col-xs-6");
      MobileAppTracking.gaTrackClickedEmailAddressBackLink(eventLabel, eventLabelId);
    });
  },

  setFormAndHeaderForProgramForm: function(page_header_text){
    jQuery(".cui-homepage-ibox").removeClass("cui-homepage");
    jQuery(".cjs_verify_org").show();
    jQuery(".cjs_verify_email_address").hide();
    jQuery(".cjs_chronus_logo_mobile").replaceWith("<span class='cjs_mobile_email_address_back_link'><i class = 'fa fa-chevron-left theme-font-color font-bold back_link p-m'></i>" + page_header_text +"</span>");
    jQuery("#mobile_header_links").hide();
    jQuery(".cjs_statusbar_header_theme_div").removeClass("col-xs-6").addClass("col-xs-12");
  },
  
  updateQueryString: function (key, value, url) {
    if (!url) url = window.location.href;
    var re = new RegExp("([?&])" + key + "=.*?(&|#|$)(.*)", "gi"),
        hash;

    if (re.test(url)) {
      if (typeof value !== 'undefined' && value !== null)
        return url.replace(re, '$1' + key + "=" + value + '$2$3');
      else {
        hash = url.split('#');
        url = hash[0].replace(re, '$1$3').replace(/(&|\?)$/, '');
        if (typeof hash[1] !== 'undefined' && hash[1] !== null) 
          url += '#' + hash[1];
        return url;
      }
    }
    else {
      if (typeof value !== 'undefined' && value !== null) {
        var separator = url.indexOf('?') !== -1 ? '&' : '?';
        hash = url.split('#');
        url = hash[0] + separator + key + '=' + value;
        if (typeof hash[1] !== 'undefined' && hash[1] !== null) 
          url += '#' + hash[1];
        return url;
      }
      else
      return url;
    }
  }
}