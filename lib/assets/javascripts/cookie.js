function strip(string) {
  return string.replace(/^\s+/, '').replace(/\s+$/, '');
}

function Cookies(path, domain) {
    this.path = path || '/';
    this.domain = domain;

    // Sets a cookie
    this.set = function(key, value, days) {
        if (typeof key != 'string') {
            throw "Invalid key";
        }
        if (typeof value != 'string' && typeof value != 'number') {
            throw "Invalid value";
        }
        if (days && typeof days != 'number') {
            throw "Invalid expiration time";
        }
        var setValue = key+'='+escape(new String(value));
        if (days) {
            var date = new Date();
            date.setTime(date.getTime()+(days*24*60*60*1000));
            var setExpiration = "; expires="+date.toGMTString();
        } else var setExpiration = "";
        var setPath = '; path='+escape(this.path);
        var setDomain = (this.domain) ? '; domain='+escape(this.domain) : '';
        var cookieString = setValue+setExpiration+setPath+setDomain;
        document.cookie = cookieString;
    },
    // Returns a cookie value or false
    this.get = function(key) {
        var keyEquals = key+"=";
        var value = false;
        cookie_values = document.cookie.split(';');
        for(var i=0; i < cookie_values.length; i++)
        {
          s = strip(cookie_values[i]);
          if (s.indexOf(keyEquals) === 0) {
            value = unescape(s.substring(keyEquals.length, s.length));
            break;
          }
        }
        return value;
    },
    // Clears a cookie
    this.clear = function(key) {
        this.set(key,'',-1);
    },
    // Clears all cookies
    this.clearAll = function() {
        cookie_values = document.cookie.split(';');
        cookie_keys = new Array();
        for(var i = 0; i < cookie_values.length; i++)
          cookie_keys[i] = strip(s.split('=').first());
        for(var i = 0; i < cookie_keys.length; i++)
          this.clear(cookie_keys[i]);
    }
};