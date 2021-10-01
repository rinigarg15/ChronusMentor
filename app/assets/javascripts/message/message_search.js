var MessageSearch = {

  initializeActions: function(){
    MessageSearch.initializeCancelSearch();
    MessageSearch.initializeTextSearchSubmit();
  },

  initializeTextSearchSubmit: function(){
    jQuery('input#search_content').live("keypress", function(e) {
      var code = (e.keyCode ? e.keyCode : e.which);
      if (code == 13) {
//        e.preventDefault();
//        e.stopPropagation();
        jQuery(this).closest('form').submit();
      }
    });
  },

  initializeCancelSearch: function(){
    var cancelSearch = jQuery(".cancel-search");
    cancelSearch.on('click', function(event){
      event.preventDefault();
      cancelSearch.addClass('hidden');
      jQuery("#search_content").val('');
      MessageSearch.applyFilters();
    });
  },

  initializeTabs: function(active_tab){
    jQuery('#cjs_messages_tabs').on('click', 'li:not(.active)',function(e){
      e.preventDefault();
      var tab = jQuery(this).data('tab');
      jQuery('#search_filter_form input#tab_number').val(tab);
      jQuery('#cjs_messages_tabs li').toggleClass('active');
      jQuery('.cjs_messages_list').toggleClass('hide');
      MessageSearch.setFilterCount(tab);
    });
    if(active_tab){
      jQuery('#cjs_'+active_tab+'_messages_tab').click();
    }
  },

  setFilterCount: function(active_tab) {
    active_filter_count = "<i class='fa-fw m-r-xs " + jQuery("#cjs_see_n_results").data("icon-class") + "'></i>";
    active_filter_count += jQuery("#cjs_see_n_results").data(active_tab + "-tab-count");
    jQuery('#cjs_see_n_results').html(active_filter_count);
  },

  showLoading: function() {
    jQuery('#loading_results').show();
  },

  applyFilters: function() {
    jQuery('#search_filter_form').submit();
    return false;
  },

  clearFilter: function(reset_id)
  {
    jQuery("#filter_pane").find('#reset_filter_' + reset_id).trigger('click');
  },

  resetStatusFilters: function(){
    jQuery('#filter_pane input[id^="search_filters_status_"]').attr("checked", false);
    MessageSearch.applyFilters();
  },

  resetSearchFilters: function(){
    jQuery("#filter_pane input#search_content").val('');
    MessageSearch.applyFilters();
  },

  initializeMemberFilters: function(){
    jQuery(document).on("click", ".ui-autocomplete", function(){
      jQuery("#messages_filter").addClass("open")
    });
    jQuery(document).ready(function() {
      initialize.jQueryAutoComplete();
    });
  }
}