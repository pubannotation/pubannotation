// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require jquery-ui
//= require autocomplete-rails
//= require jquery.facebox
//= require_tree .

getURLParameter = function(parameterName){
  var sPageURL = window.location.search.substring(1);
  var sURLVariables = sPageURL.split('&');
  for (var i = 0; i < sURLVariables.length; i++) 
  {
    var sParameterName = sURLVariables[i].split('=');
    if (sParameterName[0] == parameterName) 
    {
      return sParameterName[1];
    }
  }
}

changeAddressBarUrl = function(url){
  window.history.pushState({"html": url}, "Title", url);
}

changeAddressBarUrlForProjectsParams = function(projectNames){
  if (projectNames.length > 0){
    changeAddressBarUrl(window.location.pathname + '?projects=' +  projectNames.join(','));
  }else{
    changeAddressBarUrl(window.location.pathname);
  };
}
