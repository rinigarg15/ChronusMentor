var MilestoneTemplates = {
  addNewMilestoneSelector: "#cjs_add_milestone_template",
  milestoneTemplateSubmitBtns: ".cjs_milestone_template_submit_btn",
  editLink: ".cjs_milestone_template_edit_link",
  cancelLink: ".cjs_milestone_template_cancel_link",
  editForm: ".cjs_milestone_edit_form",
  descriptionContainer: ".cjs_description_container",
  entity: ".cjs_milestone_template_entity",
  selectorPrefix: "#cjs_milestone_template_",
  milestoneContentEnclosure: "#cjs_milestone_templates",
  milestoneForms: ".cjs_milestone_template_form",
  taskTemplateContainerPrefix: "#cjs_milestone_task_templates_",

  initialize: function(){
    jQuery(document).ready(function(){
      MilestoneTemplates.inspectAddNewMilestone();
      MilestoneTemplates.inspectEditLink();
      MilestoneTemplates.validateForm();
      MilestoneTemplates.inspectCancelLink();
      MentoringModels.taskRelated();
      MilestoneTemplates.hoverMilestoneSummary();
      MilestoneTemplates.showMilestoneTemplateEditOnClick();
      MilestoneTemplates.handleMilestoneTemplateShowOnCollapse();
    });
  },

  hoverMilestoneSummary: function() {
    jQuery(document).on("mouseenter", ".cjs-display-edit-icon", function(event){
      if(jQuery(this).closest('.cjs_milestone_template_entity').find('.cjs_milestone_edit_form').is(":hidden")) {
        jQuery(this).find(".cjs-milestone-hover-actions").removeClass('invisible');
      }
    });
    jQuery(document).on("mouseleave", ".cjs-display-edit-icon", function(event){
      jQuery(this).find(".cjs-milestone-hover-actions").addClass('invisible');
    });
  },

  inspectEditLink: function(){
    jQuery(document).on("click", MilestoneTemplates.editLink, function(event){
      event.preventDefault();
      var openForms = jQuery(MilestoneTemplates.milestoneForms);
      var milestoneEntity = jQuery(this).closest(MilestoneTemplates.entity);
      var editForm = milestoneEntity.find(MilestoneTemplates.editForm);
      var description = milestoneEntity.find(MilestoneTemplates.descriptionContainer);
      var allDescriptions = jQuery(MilestoneTemplates.descriptionContainer);
      jQuery.ajax({
        url: jQuery(this).attr("href"),
        success: function(content){
          MilestoneTemplates.resetMilestoneAccordion(openForms.not(editForm), allDescriptions.not(description));
          editForm.html(content);
          editForm.slideDown();
          description.hide();
        }
      });
    });
  },

  resetMilestoneAccordion: function(formEnclosureObjects, descriptionObjects){
    descriptionObjects.show();
    formEnclosureObjects.slideUp();
  },

  inspectCancelLink: function(){
    jQuery(document).on("click", MilestoneTemplates.cancelLink, function(event){
      event.preventDefault();
      closeQtip();
      var milestoneFormCancelLink = jQuery(this);
      var milestoneEntity = milestoneFormCancelLink.closest(MilestoneTemplates.entity);
      milestoneEntity.find(MilestoneTemplates.editForm).slideUp();
      milestoneEntity.find(MilestoneTemplates.descriptionContainer).show();
    });
  },

  inspectAddNewMilestone: function(){
    jQuery(MilestoneTemplates.addNewMilestoneSelector).on("click", function(event){
      event.preventDefault();
      jQueryShowQtip('#inner_content', 600, jQuery(this).attr("href"), "",{modal: true});
    });
  },

  appendTemplate: function(content, prevTemplateId, nextTemplateId){
    var milestoneTemplateEnclosure = jQuery(MilestoneTemplates.milestoneContentEnclosure);
    var milestoneContentContainer = milestoneTemplateEnclosure.find(".cjs_milestone_template_container");
    var noContentEnclosure = milestoneTemplateEnclosure.find(".cjs_milestone_template_no_content");
    noContentEnclosure.addClass("hide");

    if(prevTemplateId){
      jQuery(content).insertAfter(jQuery("#cjs_milestone_template_" + prevTemplateId.toString()));
    }
    else if(nextTemplateId){
      jQuery(content).insertBefore(jQuery("#cjs_milestone_template_" + nextTemplateId.toString())); 
    }
    else{
      milestoneContentContainer.append(content);
    }
  },

  replaceTemplate: function(milestoneTemplateId, content){
    jQuery(MilestoneTemplates.selectorPrefix + milestoneTemplateId).replaceWith(content);
  },

  removeTemplate: function(milestoneTemplateId){
    jQuery(MilestoneTemplates.selectorPrefix + milestoneTemplateId).remove();
    if(jQuery(MilestoneTemplates.entity).length == 0){
      jQuery(MilestoneTemplates.milestoneContentEnclosure).find(".cjs_milestone_template_no_content").removeClass("hide");
    }
  },

  validateForm: function(){
    jQuery(document).on("click", MilestoneTemplates.milestoneTemplateSubmitBtns, function(){
      var form = jQuery(this).closest("form");
      var titleObj = form.find(".cjs_milestone_template_title");
      var validTitle = (!(titleObj.val().blank()));
      if(validTitle) {
        ChronusValidator.ErrorManager.HideFieldError(titleObj);
      } else {
        ChronusValidator.ErrorManager.ShowFieldError(titleObj);
      }
      if(MentoringModels.should_sync) {
        if(validTitle) {
          MilestoneTemplates.formId = jQuery(this).closest('form').attr('id');
          chronusConfirm(MentoringModelTranslations.syncToGroupConfirmation, function() {
            jQuery("#" + MilestoneTemplates.formId).submit();
            MilestoneTemplates.formId = '';
          }, function() {
            MilestoneTemplates.formId = '';
          });
        }
        return false;
      } else {
        return validTitle;
      }
    });
  },

  refreshTasks: function(milestoneTemplateId, content, mergeTop){
    var containerSelector = MilestoneTemplates.taskTemplateContainerPrefix + milestoneTemplateId;
    var containerObject = jQuery(containerSelector);
    var hasMilestoneFeature = containerObject.length;
    MentoringModels.removeMentoringModelForms();
    if(hasMilestoneFeature){
      containerObject.html(content);
      var formLinkEnclosure = containerObject.closest(".cjs_display_task_templates").find('.cjs-add-task-form-link');
      if(typeof mergeTop != "undefined"){
        MilestoneTemplates.toggleMergeTop(formLinkEnclosure, mergeTop);
      }

    }
    else{
      var formLinkEnclosure = jQuery('.cjs-add-task-form-link');
      jQuery(".cjs-mm-task-templates-list-container").html(content);
      if(typeof mergeTop != "undefined"){
        MilestoneTemplates.toggleMergeTop(formLinkEnclosure, mergeTop);
      }
    }
    MentoringModels.showAddNewAction();
    closeQtip();
  },

  toggleMergeTop: function(formLinkEnclosure, mergeTop){
    if(mergeTop == "true"){
      formLinkEnclosure.addClass('merge-top');
    }
    else{
      formLinkEnclosure.removeClass('merge-top');
    }
  },

  showMilestoneTemplateEditOnClick: function(){
    jQuery(document).on("click", ".cjs_edit_milestone_template", function(event){
      var url = jQuery(this).attr('data-url');
      jQueryShowQtip("#inner_content", 600, url, "", {modal: true});
    });
  },

  handleMilestoneTemplateShowOnCollapse: function() {
    jQuery(document).on("click", ".cjs_show_on_collapse_milestone_template_handler", function(event){
      var templateId = jQuery(this).data('milestone-template-id');
      var linkObjectTemplate = jQuery("#collapsible_pane_milestone_" + templateId);
      var showOnCollapseTemplate = linkObjectTemplate.find(".cjs_show_on_collapse_milestone_template");
      showOnCollapseTemplate.fadeToggle("fast");
    });
  }
}
