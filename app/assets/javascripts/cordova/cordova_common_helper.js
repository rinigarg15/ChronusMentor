var iframeDetails = {
  iframeHosts: []
};

var isModalOpen = false;

var backButtonClicked = false;

var colorUtils = {
  rgb2hex: function(rgbString){
    var rgb = rgbString.match(/\d+/g);
    return ('#'+ colorUtils.hex(rgb[0]) + colorUtils.hex(rgb[1]) + colorUtils.hex(rgb[2]));
  },

  isLightColor: function(rgbString){
    var rgb = rgbString.match(/\d+/g);
    return ((Number(rgb[0]) + Number(rgb[1]) + Number(rgb[2]))/3) > 127;
  },

  hex: function(integerValue){
    return ("0" + Number(integerValue).toString(16)).slice(-2); // Single digit values has to padded with zero manually
  }
};

var statusBarHelper = {
  // Set the IOS's statusbar color and font color based on current theme color
  // StatusBar is Cordova's plugin
  updateStatusBar: function(headerId){
    if(jQuery(headerId).length > 0){
      if(window.cordova && StatusBar){
        var rgbColor = jQuery(headerId).css('background-color');
        StatusBar.backgroundColorByHexString(colorUtils.rgb2hex(rgbColor));
        colorUtils.isLightColor(rgbColor) ? StatusBar.styleDefault() : StatusBar.styleLightContent();
      }
    }
  }
};


var DeviceHelper = {

  isAndroidDevice: function(){
    return !(typeof(device) == "undefined") && (device.platform == "Android");
  },

  isKitKatAndroidDevice: function(){
    return DeviceHelper.isAndroidDevice() && device.version == "4.4.2";
  }

};

var InAppBrowserHelper = {
  
  inAppBrowserOptions: function(){
    if(DeviceHelper.isAndroidDevice()){
      return "location=yes,hardwareback=no";
    }
    else{
      return "location=no";
    }
  }

};


var cordovaFileHelper = {

  handleFileDownload: function(){
    jQuery(document).on("click", ".cjs_android_download_files", function(e){
      e.preventDefault();

      var targetUrl = jQuery(this).data("targeturl");
      var fileName = jQuery(this).data("filename");

      cordovaFileHelper.handleDownloadPermission(fileName, targetUrl);
    });
  },

  handleAttachmentDownload: function(){
    jQuery(document).on("click", ".cjs_android_download_ckeditor_files", function(e){
      e.preventDefault();
      var url = jQuery(this).attr("href");
      jQuery.ajax(url);
    });
  },

  handleDownloadPermission: function(fileName, targetUrl){
    var permissions = cordova.plugins.permissions;
    permissions.hasPermission(permissions.WRITE_EXTERNAL_STORAGE, cordovaFileHelper.writePermissionCallback.bind(this, fileName, targetUrl), null);
  },

  writePermissionCallback: function(fileName, targetUrl, status) {
    var permissions = cordova.plugins.permissions;
    if(!status.hasPermission) {
      permissions.requestPermission(permissions.WRITE_EXTERNAL_STORAGE,
        function(status) {
          if(status.hasPermission){
            cordovaFileHelper.performFileDownload(fileName, targetUrl);
          }
        },
        function(){});
    }
    else{
      cordovaFileHelper.performFileDownload(fileName, targetUrl);
    }
  },

  performFileDownload: function(fileName, targetUrl){ 
    HybridNav.getDownloadPath(fileName, function(data){
      var filePath = data.fileDownloadPath;
      var ft = new FileTransfer();

      toastr.success(mobileTranslations.downloadStarted, '', {timeOut: 2000});
    
      ft.download(targetUrl, 
        filePath, 
        cordovaFileHelper.handleDownloadComplete.bind(this, filePath), 
        cordovaFileHelper.fileDownloadFailed);
    });
  },

  handleDownloadComplete: function(filePath, entry){
    HybridNav.addFilesInDownloadApp(filePath);
  },

  fileDownloadFailed: function(error){
    toastr.error(mobileTranslations.downloadFailed);
  }
};


var cordovaNetworkHelper = {
  isOffline: false,
  reloadIframe: false,
  WhitelistHosts: [],

  handleExternalURLs: function(){
    jQuery("a.cjs_external_link").click(function(e){
      e.preventDefault();
      IAB.open(jQuery(e.currentTarget).attr('href'), '_blank', InAppBrowserHelper.inAppBrowserOptions());
    });
  },

  handleExternalLogout: function(){
    jQuery(".cjs_signout_link").click(function(e){
      jQuery(".cjs_iab_logout_redirect").addClass("cjs_signout_link_clicked");
      return true;
    });
  },

  handleOffline: function(){
    toastr.clear();
    toastr.warning(mobileTranslations.offlineMessage, '', {"preventDuplicates": true});
    cordovaNetworkHelper.isOffline = true;
    cordovaNetworkHelper.bindNetworkRetry();
    jQuery('body').on('click', cordovaNetworkHelper.showOfflineToastr);
  },

  showOfflineToastr: function(event){
    if(cordovaNetworkHelper.isOffline == true){
      event.stopPropagation();
      event.preventDefault();
      toastr.warning(mobileTranslations.offlineMessage, '', {"preventDuplicates": true});
    }
    else{
      return true;
    }
  },

  handleOnline: function(){
    if(cordovaNetworkHelper.isOffline == true){
      toastr.clear();
      toastr.remove(); // added this to fix android issue
      toastr.success(mobileTranslations.connectedNow, '', {timeOut: 3000});
      jQuery('body').off('click', cordovaNetworkHelper.showOfflineToastr);
    }
    cordovaNetworkHelper.isOffline = false;
  },

  checkNetworkStatus: function(){
    var networkState = navigator.connection.type;
    if(networkState != Connection.NONE){
      toastr.remove();
      toastr.success(mobileTranslations.connectedNow, '', {timeOut: 3000});
    }
  },

  bindNetworkRetry: function(){
    jQuery( ".cjs_check_network" ).click(function() {
      cordovaNetworkHelper.checkNetworkStatus();
    });
  },

  setDefaultHosts: function(defaultHosts){
    if (jQuery.isEmptyObject(defaultHosts)){
      HybridNav.resetDefaultHostChr();
    }
    else{
      HybridNav.setDefaultHostChr(defaultHosts);
    }
  },

  handleOnlineOpenUrl: function(url){
    HybridNav.resetDefaultHostChr();
    var parsedUrl = mobileIntermediateHost + "/mobile_v2/home/verify_organization?open_url=" + encodeURIComponent(url);
    window.location.href = parsedUrl;
  },

  isIframePresentWithSrc: function(url){
    var iframeSources = [];
    jQuery('iframe').each(function(){
      var dummyAnchor = document.createElement("a");
      dummyAnchor.setAttribute("href", jQuery(this).attr('src'));
      if(dummyAnchor.hostname!=""){
        iframeSources.push(cordovaNetworkHelper.getUrlWithoutProtocol(dummyAnchor.href));
      }
    });
    var position = jQuery.inArray(url, iframeSources);
    if (position != -1){
      return true;
    }
    else{
      return false;
    }
  },

  updateAllFrameSource: function(){
    jQuery('iframe').each(function(){
      var dummyAnchor = document.createElement("a");
      dummyAnchor.setAttribute("href", jQuery(this).attr('src'));
      if(dummyAnchor.hostname!="" && (dummyAnchor.protocol != "gap:")){
        iframeDetails.iframeHosts.push(dummyAnchor.hostname);
      }
    });
    HybridNav.setChrDefaultWhitelistHosts(iframeDetails.iframeHosts);
    setTimeout(cordovaNetworkHelper.reloadFrameAndUpdateHosts, 300);
  },

  reloadFrameAndUpdateHosts: function(){
    jQuery('iframe').each(function(){
      var src = jQuery(this).attr('src');
      jQuery(this).attr('src', src);
    });
    SpinnerPlugin.activityStop();
    jQuery('iframe').each(function(){
      jQuery(this).on('load', cordovaNetworkHelper.resetChrDefaultWhitelistHosts.bind(this, jQuery(this).attr('src')));
    });
  },

  resetChrDefaultWhitelistHosts: function(source, event){
    var dummyAnchor = document.createElement("a");
    dummyAnchor.setAttribute("href", source);
    if(dummyAnchor.hostname!=""){
      var hostname = dummyAnchor.hostname;
      iframeDetails.iframeHosts.splice(jQuery.inArray(hostname, iframeDetails.iframeHosts),1);
      HybridNav.setChrDefaultWhitelistHosts(iframeDetails.iframeHosts);
    }
  },

  getUrlWithoutProtocol: function(url){
    return url.replace(/^http[s]?:\/\//i, "");
  }
};

var forceUpdate = {
  appForceUpdate: function(options){
    var appVersion = AppVersion.version;
    if(options.latestAppVersion > appVersion){
      this.appStoreLink = options.appStoreLink;
      navigator.notification.alert(
        mobileTranslations.updateContent,
        forceUpdate.updateApp,
        mobileTranslations.updateHeader,
        mobileTranslations.updateConfirmation
      );
    }
  },

  updateApp: function(){
    var appLink = forceUpdate.appStoreLink;
    IAB.open(appLink, '_system', InAppBrowserHelper.inAppBrowserOptions());
  }
};

/* XXX: Any change made to pushNotificationHelper should be ported to Mobile as well */
var pushNotificationHelper = {
  push: null,
  toastrOptions: {
        "closeButton": true,
        "progressBar": true,
      "positionClass": "toast-bottom-left",
       "showDuration": "400",
       "hideDuration": "1000",
            "timeOut": "10000",
    "extendedTimeOut": "10000",
         "showEasing": "swing",
         "hideEasing": "linear",
         "showMethod": "fadeIn",
         "hideMethod": "fadeOut",
          "iconClass": "fa-bell lazur-bg",
        "containerId": "push-notification-toast-container"
  },
  initialize: function(options){
    pushNotificationHelper.initHandler(options);
  },

  initHandler: function(options) {
    this.push = PushNotification.init({
      ios: {
        alert: true,
        badge: true,
        sound: true
      },
      android: {
        senderID: options.gcmId,
        sound: true
      }
    });
    this.push.on('notification', this.onNotification);
    /* We will refresh device token once a day per session for perf reasons */
    if(options && options.register)
      this.push.on('registration', this.onRegistration.bind(this, options.deviceRegisterPath));
  },

  /* This function will be called on 'registration' event. We use this to refresh device token of current device */
  onRegistration: function(registrationPath, data) {
    if(data.registrationId) {
      jQuery.ajax({
        url: registrationPath,
        data: {device_token: data.registrationId},
        method: 'POST'
      });
    }
  },

  onNotification: function(data) {
    /* Case 1: Notification received in foreground */
    if(data.additionalData.foreground) {
      pushNotificationHelper.handleFGNotification(data);
    }
    /* Case 2: Notification received in background */ 
    else {
      HybridNav.isAppActive(
        function(HybridNavData){ /* Success handler */
          /* Case 2.1: Notification received while app WAS in background and is woken up by user clicking on notification */
          if(HybridNavData.isAppActive){
            pushNotificationHelper.handleNotification(data);
          }
          /* Case 2.2: Notification received while app IS in background and is woken up to do some background processing(content-available=1) */
          else {
            // todo: define what to do if notification is received in background
            pushNotificationHelper.handleNotification(data); //adding this to fix the s7 issue.
          }
        }, function(error){ /* Failure Handler */ }
      );
    }
  },

  handleNotification: function(data) {
    if(data.additionalData.url) {
      cordovaNetworkHelper.handleOnlineOpenUrl(data.additionalData.url);
    }
  },

  handleFGNotification: function(data) {
    var options     = pushNotificationHelper.toastrOptions;
    options.onclick = function(){ pushNotificationHelper.handleFGNotificationClick(data); };
    notificationToastr.info(data.message, '', options);
  },

  handleFGNotificationClick: function(data){
    var dummyAnchor = document.createElement("a");
    dummyAnchor.setAttribute("href", data.additionalData.url);
    currentHost = window.location.hostname;
    notificationHost = dummyAnchor.hostname;
    if((currentHost == notificationHost) && data.additionalData.foreground){
      window.location.href = data.additionalData.url;
    }
    else{
      pushNotificationHelper.handleNotification(data);
    }
  }
};

var IAB = {
  isAutoClose: false,
  //Do not load iframes in IAB
  open: function(url, target, options) {
    if(DeviceHelper.isKitKatAndroidDevice()){
      window.location.href = url;
    }
    else{
      var dummyAnchor = document.createElement("a");
      dummyAnchor.setAttribute("href", url);
      var urlWithoutProtocol = cordovaNetworkHelper.getUrlWithoutProtocol(dummyAnchor.href);
      if(cordovaNetworkHelper.isIframePresentWithSrc(urlWithoutProtocol)){
      }
      else{
        var ref = cordova.InAppBrowser.open(url, target, options);
        ref.addEventListener('loadstart', IAB.loadStartCallback.bind(this, ref));
        ref.addEventListener('exit', IAB.closeCallback.bind(this, ref));
      }
    }
  },

  loadStartCallback: function(ref, event) {
    jQuery.rails.enableFormElements(jQuery(jQuery.rails.formSubmitSelector));
    var closeIABAndRefresh = IAB.parseURL(event.url, 'cjs_close_iab_refresh');
    var closeIAB = IAB.parseURL(event.url, 'cjs_close_iab');
    if (closeIAB){
      ref.close();
    }
    else if(closeIABAndRefresh) {
      IAB.isAutoClose = true;
      ref.close();
      window.location.href = event.url;
    }
    SpinnerPlugin.activityStop();
  },

  closeCallback: function(ref, event) {
    jQuery(".cjs_current_linkedin_link").prop("disabled", false);
    if(jQuery(".cjs_iab_logout_redirect.cjs_signout_link_clicked").length > 0){
      window.location.href = jQuery(".cjs_iab_logout_redirect.cjs_signout_link_clicked")[0].href;
    }

    if(jQuery(".cjs_iab_handle_redirect.cjs_iab_handle_redirect_clicked").length > 0){
      if(IAB.isAutoClose == false){
        window.location.href = jQuery(".cjs_iab_handle_redirect.cjs_iab_handle_redirect_clicked")[0].href;
      }
    }
  },

  parseURL: function(url, sParam) {
    var dummyAnchor   = document.createElement('a');
    dummyAnchor.href  = url;
    var sPageURL      = decodeURIComponent(dummyAnchor.search.substring(1));
    var sURLVariables = sPageURL.split('&'), sParameterName, i;
    for (i = 0; i < sURLVariables.length; i++) {
      sParameterName = sURLVariables[i].split('=');
      if (sParameterName[0] === sParam) { return sParameterName[1] === undefined ? true : sParameterName[1]; }
    }
  }
};

var browserTab = {
  open: function(url, iabOptions) {
    cordova.plugins.browsertab.isAvailable(function(result) {
      if (!result) {
        cordova.InAppBrowser.open(url, "_system", iabOptions);
      } else {
        cordova.plugins.browsertab.openUrl(url);
      }
    });
  }
};

var appVisibility = {
  hidden: false,
  handlePause: function(){
    appVisibility.hidden = true;
  },

  handleResume: function(){
    setTimeout(function () { 
      appVisibility.hidden = false;
    }, 650);
  }
}

var backLinkHelper = {
  setAppBackUrl: function(){
    jQuery(".cjs_page_back_link_clicked").on('click', function(event){
      event.preventDefault();
    });

    jQuery(".cjs_page_back_link").on('click', function(event){
      jQuery(this).removeClass(".cjs_page_back_link");
      jQuery(this).addClass(".cjs_page_back_link_clicked");
      jQuery(this).on('click', function(event){
        event.preventDefault();
      });
      var fromSelectOrg = IAB.parseURL(window.location, 'cjs_from_select_org');
      if((window.history.length < 3) || (jQuery(".cui-homepage").length > 0) || fromSelectOrg) {
        event.preventDefault();
        backLinkHelper.handleAppExit();
      }
      else{
        event.preventDefault();
        window.history.back();
      }
    });
  },

  checkModal: function(){
    jQuery(document).on('shown.bs.modal', function(e) {
      isModalOpen = true;
    })
    jQuery(document).on('hidden.bs.modal', function(e) { 
      isModalOpen = false;
    })
  },

  hideHomeBackButton: function(){
    jQuery(document).ready(function(){
      if((jQuery(".cui-homepage").length > 0) && (jQuery(".cjs_page_back_link").length > 0)){
        jQuery(".cjs_page_back_link_container").addClass("hide");
      }
    });
  },

  onBackKeyDown: function(pageHeaderText, event){
    if(!appVisibility.hidden){
      var fromSelectOrg = IAB.parseURL(window.location, 'cjs_from_select_org');
      if(isModalOpen){
        event.preventDefault();
        jQuery(".modal.fade.in:not('.cjs_no_keyboard')").modal('hide');
      }
      else if(jQuery('#sidebarLeft').is(":visible")){
        jQuery("#content_wrapper").trigger('click');
      }
      else if(cordovaNetworkHelper.isOffline){
        toastr.clear();
        toastr.warning(mobileTranslations.offlineMessage, '', {"preventDuplicates": true});
        return;
      }
      else if(jQuery('.row-offcanvas-right').hasClass('active')){
        offCanvasHelper.initiateToggle();
      }
      else if(jQuery('.back_link').length > 0){
        jQuery('.back_link').trigger('click');
        jQuery('.cjs_mobile_email_address_back_link').trigger('click');
      }
      else if((window.history.length < 3) || (jQuery(".cui-homepage").length > 0) || fromSelectOrg){
        backLinkHelper.handleAppExit();
      }
      else{
        window.history.back();
      }
    }
  },
  
  resetBackbutton: function(){
    backButtonClicked = false;
  },

  handleAppExit: function(){
    if(backButtonClicked){
      navigator.app.exitApp();
    }
    else{
      backButtonClicked = true;
      toastr.warning(mobileTranslations.exitApp, '', {timeOut: 2500});
      setTimeout(backLinkHelper.resetBackbutton, 3000);
    }
  }
}