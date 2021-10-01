/*
 * 2.3.11 update http://groups.google.com/group/rubyonrails-security/browse_thread/thread/2d95a3cc23e03665?pli=1
 */

jQuery(document).ajaxSend(function(e, xhr, options) {
    var token = jQuery("meta[name='csrf-token']").attr("content");
    xhr.setRequestHeader("X-CSRF-Token", token);
    
    // Ajax setup (not related to 2.3.11 update) for issues described at 
    // http://stackoverflow.com/questions/4533743/ajax-comments-not-working-in-rails-3-0-3 and
    // https://github.com/rails/jquery-ujs/issues/52
    xhr.setRequestHeader("Accept", "text/javascript");

    /* Google Analytics track */
    Analytics._trackAjax(options.url);
});


jQuery.extend({
  put: function(url, data, callback, type) {
    return _ajax_request(url, data, callback, type, 'PATCH');
  },
  delete_: function(url, data, callback, type) {
    return _ajax_request(url, data, callback, type, 'DELETE');
  }
});

function _ajax_request(url, data, callback, type, method) {
  if (jQuery.isFunction(data)) {
    callback = data;
    data = {};
  }
  return jQuery.ajax({
    type: method,
    url: url,
    data: data,
    success: callback,
    dataType: type
  });
}

jQuery.fn.submitWithAjax = function() {
  this.unbind('submit', false);
  this.live('submit', function() {
    jQuery.post(this.action, jQuery(this).serialize(), null, "script");
    return false;
  });

  return this;
};

jQuery.fn.submitWithAjaxWithValidation = function() {
  this.unbind('submit', false);
  this.live('submit', function() {
    if (jQuery(this).attr('validationFunc') != '')
    {
      if (!eval(jQuery(this).attr('validationFunc')))
      {
        return false;
      }
    }
    if (jQuery(this).attr('loadingFunc') != '')
      eval(jQuery(this).attr('loadingFunc'));
    jQuery.post(this.action, jQuery(this).serialize(), null, "script");
    return false;
  });
  return this;
};

jQuery.fn.getWithAjax = function() {
  this.unbind('click', false);
  this.live('click', function() {
    jQuery.get(jQuery(this).attr("href"), jQuery(this).serialize(), null, "script");
    return false;
  });
  return this;
};
/*
  Post data via html
  Use the class post in your link declaration
  */
jQuery.fn.postWithAjax = function() {
  this.unbind('click', false);
  this.live('click', function() {
    jQuery.post(jQuery(this).attr("href"), jQuery(this).serialize(), null, "script");
    return false;
  });
  return this;
};

/*
  Update/Put data via html
  Use the class put in your link declaration
  */
jQuery.fn.putWithAjax = function() {
  this.unbind('click', false);
  this.live('click', function() {
    message = jQuery(this).attr('message');
    if (!(message == null)) {
      confirmed = confirm(message);
      if (!confirmed) {
        return false;
      }
    }
    jQuery.put(jQuery(this).attr("href"), jQuery(this).serialize(), null, "script");
    return false;
  });
  return this;
};

/*
  Delete data
  Use the class delete in your link declaration
  */
jQuery.fn.deleteWithAjax = function() {
  this.removeAttr('onclick');
  this.unbind('click', false);
  this.live('click', function() {
    var msg = jQuery(this).attr('message') || jsCommonTranslations.sureToDelete;
    confirmed = confirm(msg);
    if (!confirmed) {
      return false;
    }
    jQuery.delete_(jQuery(this).attr("href"), jQuery(this).serialize(), null, "script");
    return false;
  });
  return this;
};

jQuery.fn.addBack = jQuery.fn.andSelf;

function ajaxLinks(){
  jQuery('.submit_with_ajax').submitWithAjax();
  jQuery('.submit_ajax_with_validation').submitWithAjaxWithValidation();
  jQuery('a.get_event').getWithAjax();
  jQuery('a.post').postWithAjax();
  jQuery('a.put').putWithAjax();
  jQuery('a.delete_event').deleteWithAjax();
}