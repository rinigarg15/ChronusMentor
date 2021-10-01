//= require ../cordova_common_helper

var handleOpenURL = function(url){
  url = url.split("//")[2];
  cordovaNetworkHelper.handleOnlineOpenUrl(url);
};

// Include all common functions, which has to be executed onDeviceReady event of Android app
var cordovaPluginsHelper = {
  onLoad: function(headerId, pluginOptions, pageHeaderText){
    pluginOptions = pluginOptions || {};
    document.addEventListener("deviceready", function(){
      navigator.splashscreen.hide();
      SpinnerPlugin.activityStop();
      cordovaNetworkHelper.handleExternalURLs();
      cordovaNetworkHelper.handleExternalLogout();
      pushNotificationHelper.initialize(pluginOptions.pushNotification);
      cordovaNetworkHelper.bindNetworkRetry();
      forceUpdate.appForceUpdate(pluginOptions.appUpdate);
      cordovaNetworkHelper.setDefaultHosts(pluginOptions.defaultHosts);
      setTimeout(cordovaNetworkHelper.updateAllFrameSource, 300);
      backLinkHelper.setAppBackUrl();
      backLinkHelper.checkModal();
      cordovaFileHelper.handleFileDownload();
      cordovaFileHelper.handleAttachmentDownload();
    });
    document.addEventListener("offline", cordovaNetworkHelper.handleOffline, false);
    document.addEventListener("online", cordovaNetworkHelper.handleOnline, false);
    document.addEventListener("pause", appVisibility.handlePause, false);
    document.addEventListener("resume", appVisibility.handleResume, false);
    document.addEventListener("backbutton", function(event){ backLinkHelper.onBackKeyDown(pageHeaderText, event) }, false);
    backLinkHelper.hideHomeBackButton();
  }
};