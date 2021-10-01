var MentoringModelGoal = {

  addGoalRelatedTaskPrefix: ".cjs-add-task-form-link-",

  initialize: function() {
    MentoringModelGoal.handleGoalEvents();
    MentoringModelGoal.addNewGoal();
    MentoringModelGoal.handleGoalListEvents();
  },
  
  handleGoalEvents: function() {
    jQuery(document).on("click", ".cjs_goal_cancel_btn", function(event) {
      event.preventDefault();
      var parentElement = MentoringModelGoal.getClosestGoalData(jQuery(this));
      MentoringModelGoal.displayGoalValues(parentElement);
    });

    jQuery(document).on("click", ".cjs_goal_save_btn", function(event) {
      var parentElement = jQuery(this).closest('.cjs_goal_edit_form');
      var titleElement = parentElement.find(".cjs_goal_title");
      var emptyTitle = MentoringModelGoal.validateFields(titleElement);
      if(emptyTitle){
        jQueryScrollTo(jQuery(this).closest('.cjs_display_goal_data'))
      }
      else {
        return false;
      }
    });

  },

  handleGoalListEvents: function() {
    jQuery(document).on("click", ".cjs_handle_goal_list", function(event){
      var linkGoalObject = jQuery(this);
      var goalId = linkGoalObject.data('goal-id');
      var linkObjectGoal = jQuery(".cjs_goal_container-" + goalId);
      var showOnCollapseGoal = linkObjectGoal.find(".cjs_show_on_collapse_goal");
      var goalContent = linkObjectGoal.find(".cjs_display_goal_data_content");
      showOnCollapseGoal.fadeToggle("fast");
    });
  },

  addNewGoal: function(){
    jQuery(".cjs_add_new_goal").on('click', function(event){
      event.preventDefault();
      jQueryShowQtip('.cjs_display_all_goals', 600, jQuery(this).data("url"), "", {modal: true});
    });
  },

  validateFields: function(element) {
    if(element.val().blank()) {
      ChronusValidator.ErrorManager.ShowFieldError(element);
      return false;
    }
    else {
      ChronusValidator.ErrorManager.HideFieldError(element);
      return true;
    }

  },

  getClosestGoalData: function(targetObj) {
    return targetObj.closest(".cjs_display_goal_data");
  },

  displayGoalValues: function(parentElement) {
    parentElement.find('.cjs_goal_edit_form').slideUp("fast", function() {
      parentElement.find('.cjs_goal_display').removeClass('hide');
    });
  },


  addTaskForm: function(goalId, content) {
    MentoringModels.actionItemFormReset();
    var addTaskFormLink = jQuery(MentoringModelGoal.addGoalRelatedTaskPrefix + goalId);
    jQuery('.cjs-mentoring-model-task-form').remove();
    var responseConatiner = addTaskFormLink.closest(".cjs-form-and-menu-link-container").find(".cjs-action-item-response-container");
    responseConatiner.append(content);
    responseConatiner.show();
  }
}