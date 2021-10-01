var GoalTemplates = {

  formPrefix: "#cjs-mentoring-model-goal-template-form-",
  goalContainer: "#cjs-goal-template-container-",
  goalTitleContainerPrefix: ".cjs_goal_template_title_below_description_",
  taskTemplateDescription: ".cjs-task-template-description",

  initialize: function() {
    GoalTemplates.validateGoal();
    GoalTemplates.addNewGoal();
    GoalTemplates.descriptionToggle();
    MentoringModels.hoverEvent();
    GoalTemplates.showGoalTemplateEditOnClick();
  },

  computeGoalTemplateFormActions: function(goalTemplateId) {
    var goalTemplateForm = jQuery(GoalTemplates.formPrefix + goalTemplateId);    
    MentoringModels.closeFormAction(goalTemplateForm);
  },

  validateGoal: function() {
    jQuery(document).on("click", ".cjs_goal_template_save_btn", function(event) {
      var parentElement = jQuery(this).closest('.cjs_goal_template_edit');
      var titleElement = parentElement.find(".cjs_goal_template_title");
      var validTitle = GoalTemplates.validateFields(titleElement);
      if(MentoringModels.should_sync) {
        if(validTitle) {
          GoalTemplates.formId = jQuery(this).closest('form').attr('id');
          chronusConfirm(MentoringModelTranslations.syncToGroupConfirmation, function() {
            jQuery("#" + GoalTemplates.formId).submit();
            GoalTemplates.formId = '';
          }, function() {
            GoalTemplates.formId = '';
          });
        }
        return false;
      } else {
        return validTitle;
      }
    });
  },

  descriptionToggle: function() {
    jQuery(document).on("click", ".cjs-goal-template-title", function(){
      jQuery(this).find(".cjs-goal-template-title-raquo, .cjs-goal-template-title-laquo").toggle();
      jQuery(this).closest(".cjs-description-toggle").next(".cjs-goal-template-description").toggle();
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

  addNewGoal: function() {
    jQuery(".cjs_add_new_goal").on('click', function(event){
      event.preventDefault();
      jQuery('.cjs-mentoring-model-goal-template-form').remove();
      jQueryShowQtip('.cjs_display_new_goal', 600, jQuery(this).data("url"), "", {modal: true});
    });
  },

  addNewProgramGoal: function(url) {
    jQueryShowQtip('.cjs_display_new_goal', 500, url, "", {modal: true});
  },

  createNewGoalTemplate: function(content) {
    jQuery('.cjs-goal-template-header .cjs_display_new_goal').parent().append(content);
    jQuery('.cjs-goal-template-header .cjs_no_goal_template_msg').slideUp();
    jQuery('.cjs-goal-template-header .cjs-goal-template-horizontal-line').hide();
    closeQtip();
  },

  updateGoalTemplate: function(goalId, content, goalTitleContent) {
    var goalContainer = jQuery(GoalTemplates.goalContainer + goalId);
    var goalTitleUnderTaskTemplate = jQuery(GoalTemplates.taskTemplateDescription).find(GoalTemplates.goalTitleContainerPrefix + goalId);
    goalContainer.replaceWith(content);
    goalTitleUnderTaskTemplate.replaceWith(goalTitleContent);
    closeQtip();
  },

  handleProgressiveFormOnCloseActions: function() {
    if(TaskTemplateProgressiveForm.currentForm) TaskTemplateProgressiveForm.showMenuInvokerAndCloseForm();
    if(FacilitationTemplateProgressiveForm.currentForm) FacilitationTemplateProgressiveForm.showMenuInvokerAndCloseForm();
  },

  appendForm: function(goalId, content) {
    var editFormEnclosure = jQuery(".cjs-goal-template-edit-action-" + goalId);
    jQuery('.cjs-mentoring-model-goal-template-form').remove();
    editFormEnclosure.append(content);
    editFormEnclosure.find(".cjs-mentoring-model-goal-template-form").slideDown();
    jQuery(".cjs-goal-template-header .cjs-hover-well").closest('.cjs-mentoring-model-hover-well').removeClass('bg-hover');
    jQuery(".cjs-goal-template-header .cjs-hover-actions").addClass('invisible');
  },

  showGoalTemplateEditOnClick: function(){
    jQuery(document).on("click", ".cjs_edit_goal_template", function(event){
      var url = jQuery(this).attr('data-url');
      jQueryShowQtip("#inner_content", 600, url, "", {modal: true});
    });
  }
};

var ProgramGoals ={
  openEditPopup: function(goalId){
    jQuery(document).ready(function(){
      jQuery("#cjs_program_goal_edit_" + goalId).click();
    });
  }
}