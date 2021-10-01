var DemographicReport = {

  sortBoth: "sort_both",
  sortAsc: "sort_asc",
  sortDesc: "sort_desc",

  initializeTableView: function(){
    DemographicReport.inspectSortableColumns();
    DemographicReport.inspectCities();
  },

  inspectSortableColumns: function(){
    var sortableColumnsSelector = "tr.cjs_demographic_report_table_header th.cjs_sortable_column";
    jQuery(document).on("click", sortableColumnsSelector, function(){
      var sortParam = jQuery(this).data("sort-param");
      var sortOrder = "";

      DemographicReport.resetSortImages(jQuery(sortableColumnsSelector).not(jQuery(this)));
      if(jQuery(this).hasClass(DemographicReport.sortBoth)){
        jQuery(this).removeClass(DemographicReport.sortBoth).addClass(DemographicReport.sortAsc);
        sortOrder = "asc";
      }
      else if(jQuery(this).hasClass(DemographicReport.sortAsc)){
        jQuery(this).removeClass(DemographicReport.sortAsc).addClass(DemographicReport.sortDesc);
        sortOrder = "desc";
      }
      else if(jQuery(this).hasClass(DemographicReport.sortDesc)){
        jQuery(this).removeClass(DemographicReport.sortDesc).addClass(DemographicReport.sortBoth);
        sortOrder = "asc";
        sortParam = "country";
      }
      jQuery.ajax({
        url: jQuery(this).data("url"),
        data: {sort_order: sortOrder, sort_param: sortParam},
        beforeSend: function(){
          jQuery("#loading_results").show();
        }
      });
    });
  },

  inspectCities: function(){
    jQuery(document).on('click', ".cjs_country_field", function(){
      var countryId = jQuery(this).data("country-index");
      var cities = jQuery(".cjs_city_"+countryId);
      if(cities.hasClass('hide')){
        cities.removeClass('hide');
      }
      else{
        cities.addClass('hide');
      }
    });
  },

  resetSortImages: function(headerElements){
    headerElements.removeClass(DemographicReport.sortDesc).removeClass(DemographicReport.sortAsc).addClass(DemographicReport.sortBoth);
  },

  initializeMap: function(locations) {
    var mapOptions = {
      zoom: 0,
      minZoom: 2,
      center: new google.maps.LatLng(0, 0)
    }

    var map = new google.maps.Map(jQuery("#map-canvas")[0], mapOptions);
    DemographicReport.setMapBounds(map, locations);
    var markers = DemographicReport.setMarkers(map, locations);
    new MarkerClusterer(map, markers, {gridSize: 50, maxZoom: 15});
  },

  setMarkers: function(map, locations) {
    var markers = [];
    for (var i = 0; i < locations.length; i++) {
      var beach = locations[i];
      var myLatLng = new google.maps.LatLng(beach[1], beach[2]);
      var marker = new google.maps.Marker({
          position: myLatLng,
          map: map,
          title: beach[0],
          zIndex: beach[3]
      });
      markers.push(marker);
    }
    return markers;
  },

  setMapBounds: function(map, locations) {
    var bounds = new google.maps.LatLngBounds();
    for (var i = 0; i < locations.length; i++) {
      bounds.extend(new google.maps.LatLng(locations[i][1], locations[i][2]));
    }
    map.fitBounds(bounds);
  }
}