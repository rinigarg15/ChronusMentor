var ProgramUrlHelper = {
  getProgramRootPath: function(dummyAnchor){
    var splittedPath = dummyAnchor.pathname.split("/");
    if (splittedPath.length > 2 && splittedPath[1] == "p"){
      return dummyAnchor.pathname.split("/").slice(0,3).join("/");
    }
    else{
      return '';
    }
  },

  createAnchor: function(url) {
    var dummyAnchor = document.createElement("a");
    dummyAnchor.setAttribute("href", url);
    return dummyAnchor;
  },

  getOrganizationUrlWithProtocol: function(dummyAnchor, options) {
    var port = "";
    if(options.port != ""){
      port = ":" + options.port;
    }
    var organizationUrl = '//' + dummyAnchor.hostname + port;
    return organizationUrl;
  }
}