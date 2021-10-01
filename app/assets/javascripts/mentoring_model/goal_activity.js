var GoalActivity = {
  updateLink: ".cjs_manual_progress_goal_update_link",
  submitButton: ".cjs_manual_progress_goal_activity_submit",
  messageBox: ".cjs_manual_progress_goal_activity_message",
  slider: "#manual_slider",
  sliderinput: "#progress_slider",
  sliderEnclosure: "#cjs_slider_enclosure",
  newManualGoalMessageFormSubmitButton: ".cjs_manual_progress_goal_message_form_submit",

  initializeProgressBar: function(progressValue){
    var progress_slider = jQuery(GoalActivity.slider)[0];
    var progress_slider_value = jQuery(GoalActivity.sliderinput);
    noUiSlider.create(progress_slider, {
      start: progressValue,
      tooltips: true,
      step: 1,
      connect: "lower",
      range: {
        'min': 0,
        'max': 100
      },
      format: {
        to: function ( value ) {
          return Math.round(value);
        },
        from: function ( value ) {
          return Math.round(value);
        }
      }
    });
    progress_slider.noUiSlider.on('update', function( values, handle ){
      progress_slider_value.val(values[handle]);
    });
  },

  validateForm: function(goal_id){
    var submitButton = jQuery(GoalActivity.submitButton+"_"+goal_id);
    var form = submitButton.closest("form");
    var messageBox = form.find(GoalActivity.messageBox);
    var slider = form.find(GoalActivity.slider);
    if(messageBox.val().blank() && !GoalActivity.isSliderChanged(slider)){
      ChronusValidator.ErrorManager.ShowFieldError(slider.closest(GoalActivity.sliderEnclosure));
      return false
    }
    return true;
  },

  validateMessageForm: function(goal_id){
    var submitButton = jQuery(GoalActivity.newManualGoalMessageFormSubmitButton+"_"+goal_id);
    var form = submitButton.closest("form");
    var messageBox = form.find(GoalActivity.messageBox);
    if(messageBox.val().blank()) {
      ChronusValidator.ErrorManager.ShowFieldError(messageBox);
      return false;
    }
    return true;
  },

  isSliderChanged: function(sliderObj){
    return(sliderObj.data("current-value") != parseInt(sliderObj.val()));
  },

  inspectUpdateLink: function(){
    jQuery(document).on("click", GoalActivity.updateLink, function(event){
      event.preventDefault();
      var updateLink = jQuery(this);
      var url = updateLink.attr("href");
      var goalId = updateLink.data("goal-id");
      var dataParameters = {goal_id: goalId};
      jQueryShowQtip('#group', 450, url, dataParameters, {modal: true});
    });
  },
}