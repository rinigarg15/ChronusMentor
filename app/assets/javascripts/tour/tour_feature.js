var TourFeature = {
  COMPLETE_TOUR_TAG: "complete_tour",
  CLOSE_TOUR_IN_MIDDLE: "close_tour_in_middle",

  AnalyticsParams: {
    closeTourInMiddle: window.location.pathname + "?gid=" + this.CLOSE_TOUR_IN_MIDDLE,
    completeTour: window.location.pathname + "?gid=" + this.COMPLETE_TOUR_TAG
  },

// This function sets up the toursteps in TripSteps object.
// Once the tour is setup we need to invoke TripSteps.start(); (could be inside some onclick event) when we want to visit the tour .

//Paramters:
//1. numberOfTips: specifies the number of tip boxes in the tour (excluding the pop-up window)
//2. tipAttributes: [tipContent, selectors, highlight, direction]
//  2.1 tipContent: Array of content in the tip boxes shown during the tour
//  2.2 selectors: Array of ids/classes (selectors) for the buttons/links (html elements) where you want to show the tips during the tour
//  2.3 highlight: Array of ids/classes (selectors) for the buttons/links (html elements) where you want to highlight during the tour
//  2.4 direction: Array of direction/position of the tip box with respect to the buttons/links (html element)
//3. lessThanIE9: browser version specification.

  SetupTrip: function(numberOfTips, tipAttributes, lessThanIE9) {

    var TripSteps = TourFeature.setContent(numberOfTips, tipAttributes, lessThanIE9);
    return TripSteps;
  },



  setContent: function(numberOfTips, tipAttributes, lessThanIE9){

    var basicBlock = "<div class='popover tour'><div class='arrow'></div><h3 class='popover-title'></h3><div class='popover-content'></div> <div class='popover-navigation gray-bg'> <div class='btn-group'> <button class='btn btn-sm btn-white' data-role='prev'>" + jsTourTranslation.prevLabelHelptText + "</button> <button class='btn btn-sm btn-primary' data-role='next'>" + jsTourTranslation.nextLabelHelptText + "</button>  </div> <button class=' btn-sm btn btn-white' data-role='end'>" + jsTourTranslation.finishLabelHelptText + "</button> </div></nav>      </div>";
    TripSteps = new Tour(
      {
        steps: TourFeature.setContentSteps(numberOfTips, tipAttributes, lessThanIE9),
        showNavigation : true,
        showCloseBox : true,
        delay : false,
        animation: true,
        template: basicBlock
      }
    );

    return TripSteps;
  },

  progressContentHtml: function(numberOfTips){
    var progressElement = [];
    for (i = 0; i < numberOfTips; i++) {
      progressElementClass = "\"cui-tour-step-round-" + i.toString() + " cui-tour-step-inactive\"";
      progressElement.push('<li class=' + progressElementClass + '>' + i + '</li>');
    }
    return progressElement;
  },

  hideTrip: function(){
    jQuery(".trip-exposed").on('click', function(){
      TripSteps.stop();
    });
  },

  //Expose an element 
  showExpose: function(elt){
    if(elt.data("has-expose")){
      oldCSS = {
        position: elt.css('position'),
      };

      // we have to make it higher than the overlay
      newCSS = {
        position: 'relative',
      };

      elt.data('tour-old-css', oldCSS)
        .css(newCSS)
        .addClass('tour-exposed');
    }
    
  },

  hideExpose: function(elt) {
    if(elt.data("has-expose")){
      var oldCSS = elt.data('tour-old-css');
      elt.css(oldCSS)
        .removeClass('tour-exposed');

    }
  },

  getTourElement: function(tour){
    return tour._options.steps[tour._current].element
  },

  setContentSteps: function(numberOfTips, tipAttributes, lessThanIE9){
    var arr = []
    var expose = []
    for (i = 0; i < numberOfTips; i++) {
      // Setting Expose so that the z-Index can be brought into effect
      if( tipAttributes[4] != undefined && tipAttributes[4][i] == "expose"){
        jQuery(tipAttributes[1][i]).data("has-expose", true)
      }

      var element = {
        element: jQuery(tipAttributes[1][i]),
        content: tipAttributes[0][i],
        placement : tipAttributes[3][i],
        animation: 'fadeIn',
        backdrop: true,
        backdropPadding: "5",
        onShow: function(tour) {
          TourFeature.hideTrip();
          if (i == numberOfTips - 1) {
            Analytics.gaTrack(TourFeature.AnalyticsParams.completeTour);
          }
        },
        onShown:  function(tour) {
          TourFeature.showExpose(TourFeature.getTourElement(tour));
        },
        onHide: function(tour) {
          TourFeature.hideExpose(TourFeature.getTourElement(tour));
          if (i != numberOfTips - 1) {
            Analytics.gaTrack(TourFeature.AnalyticsParams.closeTourInMiddle);
          }
        }
      }
      arr.push(element);
    }
    return arr;
  },

  trackTourTaken: function(path, messageTag){
    jQuery.ajax({
      type: "POST",
      url: path,
      data: {TAG: messageTag}
    });
  }
};
