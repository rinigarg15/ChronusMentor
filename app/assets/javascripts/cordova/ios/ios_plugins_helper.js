//= require ../cordova_common_helper

var handleOpenUrl = function(url){
  // Keeping this fail safe as the plugin was introduced during an app-update.
  // Safari View Controller (Browsertab in iOS) should be explicity closed.
  // Refer https://github.com/google/cordova-plugin-browsertab/issues/4
  try {
    cordova.plugins.browsertab.close();
  } catch(e) {
    // Do nothing
  }

  url = url.split("//")[2];
  cordovaNetworkHelper.handleOnlineOpenUrl(url);
};

// Include all common functions, which has to be executed onDeviceReady event of IOS app
var cordovaPluginsHelper = {
  onLoad: function(headerId, pluginOptions){
    pluginOptions = pluginOptions || {};
    document.addEventListener("deviceready", function(){
      navigator.splashscreen.hide();
      statusBarHelper.updateStatusBar(headerId);
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
    });
    document.addEventListener("offline", cordovaNetworkHelper.handleOffline, false);
    document.addEventListener("online", cordovaNetworkHelper.handleOnline, false);
    backLinkHelper.hideHomeBackButton();
  }
};