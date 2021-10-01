var CoachingGoals = {
  updateLink: ".cjs_coaching_goal_update_link",
  submitButton: ".cjs_coaching_goal_activity_submit",
  messageBox: ".cjs_goal_activity_message",
  slider: "#progress_slider.slider",
  sliderEnclosure: "#cjs_slider_enclosure",
  goalsSidePaneEnclosure: ".cjs_side_pane_coaching_goals",
  activityFeedId: ".cjs_coaching_goal_activity_feed",
  newCoachingGoalMessageForm: ".cjs_new_message_coaching_goal_activity_form",

  initializeProgressBar: function(progressValue){
    jQuery(CoachingGoals.slider).slider({
      max: 100,
      value: progressValue
    })
  },

  validateForm: function(){
    var submitButton = jQuery(CoachingGoals.submitButton);
    submitButton.click(function(){
      var form = submitButton.closest("form");
      var messageBox = form.find(CoachingGoals.messageBox);
      var slider = form.find(CoachingGoals.slider);
      if(messageBox.val().blank() && !CoachingGoals.isSliderChanged(slider)){
        ChronusValidator.ErrorManager.ShowFieldError(slider.closest(CoachingGoals.sliderEnclosure));
        return false
      }
      return true;
    });
  },

  isSliderChanged: function(sliderObj){
    return(sliderObj.data("current-value") != parseInt(sliderObj.val()));
  },

  inspectUpdateLink: function(){
    jQuery(document).on("click", CoachingGoals.updateLink, function(event){
      event.preventDefault();
      var updateLink = jQuery(this);
      var url = updateLink.attr("href");
      var coachingGoalId = updateLink.data("coaching-goal-id");
      var dataParameters = {coaching_goal_id: coachingGoalId};
      jQueryShowQtip('#group', 450, url, dataParameters, {modal: true});
    });
  },

  refreshCoachingGoal: function(scopingId, content){
    jQuery(scopingId).replaceWith(content);
  },

  refreshGoalsSidePane: function(content){
    jQuery(CoachingGoals.goalsSidePaneEnclosure).replaceWith(content);
  },

  validateTitle: function(titleErrorText) {
    jQuery(".cjs_goal_submit").click(function() {
      var titleObj = jQuery("#cjs_cgoal_title");
      if (titleObj.val().blank()) {
        ChronusValidator.ErrorManager.ShowResponseFlash("coaching_goal_flash", titleErrorText);
        ChronusValidator.ErrorManager.ShowFieldError(titleObj);
        return false;
      }
    });
  },

  newGoalFormBlind: function() {
    jQuery(".cjs_goal_cancel").click(function(event){
      event.preventDefault();
      jQuery("#add_new_goal_header").click();
    });
  },

  prependGoalToListing: function(content) {
    CoachingGoals.resetAddGoalForm();
    jQuery("#cui_goals_list").html(content);
    jQueryHighlight('#cui_goals_list .well:first');
  },

  resetAddGoalForm: function() {
    jQuery(CoachingGoals.slider).slider('setValue', 0);
    jQuery(".cjs_goal_form" )[0].reset();
  },

  handleEditCancel: function(content) {
    jQuery(document).on('click', ".cjs_goal_form .cjs_goal_cancel", function(event){
      event.preventDefault();
      CoachingGoals.replaceFormWithGoal(content);
    });
  },

  replaceFormWithGoal: function (content) {
    jQuery(".cjs_goal_form").parent().replaceWith(content);
  },

  appendContent: function(content){
    jQuery(CoachingGoals.newCoachingGoalMessageForm)[0].reset();
    jQuery(content).insertAfter(CoachingGoals.activityFeedId);
  },

  validateNewMessageForm: function(){
    jQuery(CoachingGoals.newCoachingGoalMessageForm + " input[type=submit]").click(function(){
      return(!(jQuery(this).closest(CoachingGoals.newCoachingGoalMessageForm).find("textarea").val().blank()))
    })
  }
}