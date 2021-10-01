var domainCookie, sessionActiveCookieName, clientTimeDifferenceCookie, timeoutInterval, logout_url;
var AutoLogout = {
    warningTime: 60000,
    logoutLinkClicked: false,

    initAutoLogout: function(timeInterval, host, session_expiry_warning_time, session_active_cookie, client_time_difference_cookie, time, logout_path) {
     timeoutInterval = timeInterval;
     logout_url = logout_path;
     domainCookie = new Cookies('/', host);
     AutoLogout.warningTime =  session_expiry_warning_time * 1000; // In Milli Seconds
     AutoLogout.logoutLinkClicked = false;
     sessionActiveCookieName = session_active_cookie;
     clientTimeDifferenceCookie = client_time_difference_cookie;
     setTimeout("AutoLogout.checkSession()", timeoutInterval );
     AutoLogout.setClientTimeDifference(time) ;
    },

    checkSession: function() {
      var value = parseInt(domainCookie.get(sessionActiveCookieName));
      if (value){
        var milliSecondsLeft = AutoLogout.milliSecondsToExpire(value);

        if(milliSecondsLeft <= 0){
          AutoLogout.logout();
        }
        else if( milliSecondsLeft <= AutoLogout.warningTime){
          AutoLogout.showAutoLogout(value);
          setTimeout("AutoLogout.checkSession()", timeoutInterval);
        }
        else{
          AutoLogout.hideAutoLogout();
          setTimeout("AutoLogout.checkSession()", timeoutInterval);
        }

      }
      else{
        AutoLogout.logout();
      }
    },

    initAllTabLogout: function(host, session_active_cookie, timeInterval){
      timeoutInterval = timeInterval;
      domainCookie = new Cookies('/', host);
      sessionActiveCookieName = session_active_cookie;
      setTimeout("AutoLogout.checkLogout()", timeoutInterval);
    },

    checkLogout: function() {
      var value = parseInt(domainCookie.get(sessionActiveCookieName));
      if (value){
        setTimeout("AutoLogout.checkLogout()", timeoutInterval);
      }
      else{
        if(jQuery('.cjs_check_signout').length == 0){
          jQuery('.cjs_signout_link').click();
        }
      }
    },

    beforeRefreshSession: function() {
      AutoLogout.logoutLinkClicked = true;
      jQuery('#refresh_session_link').hide();
      jQuery('#auto_logout_dialog').hide();
      jQuery('#to_expire_warning').hide();
      jQuery('#logout_link').hide();
      jQuery('#logging_out_warning_header').hide();
      jQuery('#session_refresh_message').show();
      jQuery('#session_refresh_message_header').show();
    },

    afterRefreshSession: function() {
      AutoLogout.logoutLinkClicked = false;
      jQuery('#session_refresh_message_header').hide();
      jQuery('#session_refresh_message').hide();
      AutoLogout.hideAutoLogout();
    },

    logoutClick: function() {
      AutoLogout.logoutLinkClicked = true;
      AutoLogout.logout();
    },


    setClientTimeDifference: function(serverTime){
      var d = new Date();
      var timestamp = d.getTime();

      var difference = serverTime*1000 - timestamp; // In milli seconds
      domainCookie.set(clientTimeDifferenceCookie, difference); // In milli seconds
    },

    aboutToExpireIn: function(value){
      var time = Math.floor((value*1000 - AutoLogout.getCurrentTimeStamp())/1000);
      if (time <= 0) {
        return 0;
      }
      if(time > 60)
      {
        jQuery('#to_expire_warning_minutes').show();
        jQuery('#to_expire_warning_seconds').hide();
        return Math.ceil(time/60);
      }
      jQuery('#to_expire_warning_minutes').hide();
      jQuery('#to_expire_warning_seconds').show();
      return time;
    },

    milliSecondsToExpire: function(cookieValue){
      return cookieValue*1000 - AutoLogout.getCurrentTimeStamp();
    },

    getCurrentTimeStamp:function(){
      var d = new Date();
      var timestamp = d.getTime();
      return timestamp + parseInt(domainCookie.get(clientTimeDifferenceCookie)); // In milli seconds
    },

    logout: function(){
      jQuery('#logout_link').hide();
      jQuery('#auto_logout_dialog').hide();
      jQuery('#to_expire_warning').hide();
      jQuery('#refresh_session_link').hide();
      jQuery('#logging_out_warning').show();
      if(jQuery('.cjs_check_signout').length == 0){
          jQuery('.cjs_signout_link').click();
      }
    },

    showAutoLogout: function(value) {
      if(!AutoLogout.logoutLinkClicked)
      {
        jQuery('#modal_auto_logout_dialog:not(.modal.in)').modal({
          keyboard: false,
          show: true,
          backdrop: 'static'
        });

        jQuery('#auto_logout_dialog').show();
        jQuery('#to_expire_warning').show();
        jQuery('#refresh_session_link').show();
        jQuery('#logging_out_warning_header').show();
        jQuery('#session_refresh_message_header').hide();
        jQuery('#logout_link').show();
        jQuery('#logging_out_warning').hide();
        jQuery('#logout_time').html(AutoLogout.aboutToExpireIn(value));
        jQuery("body").css("overflow", "hidden");
      }
    },

    hideAutoLogout: function() {
      jQuery('#modal_auto_logout_dialog').modal('hide');
      jQuery("body").css("overflow", "auto");
    }
  };