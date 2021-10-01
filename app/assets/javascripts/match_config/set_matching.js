var MatchConfig = {
  configId: 0,
  setMatchingURL: "",
  nextIdOfSet: 0,
  studentChoices: [],
  mentorChoices: [],
  studentChoiceQuestionIds: [],
  mentorChoiceQuestionIds: [],
  studentShowLabelQuestionIds: [],
  mentorShowLabelQuestionIds: [],
  select2Separator: "",
  select2TokenSeparator: [],
  questionCompatibilityMap: [],
  setMatchingTypes: [],

  initializeQuestionSelection: function(configId, student_choice_ques_ids, mentor_choice_ques_ids, student_show_label_ques_ids, mentor_show_label_ques_ids, url_to, confirmMessage, select2Separator, multiSetSeparator, questionCompatibilityMap, setMatchingTypes){
    jQuery(document).ready(function(){
      MatchConfig.select2Separator = select2Separator;
      MatchConfig.select2TokenSeparator = [select2Separator];
      MatchConfig.multiSetSeparator = multiSetSeparator;
      MatchConfig.configId = configId;
      MatchConfig.setMatchingURL = url_to;
      MatchConfig.studentChoiceQuestionIds = student_choice_ques_ids;
      MatchConfig.mentorChoiceQuestionIds = mentor_choice_ques_ids;
      MatchConfig.studentShowLabelQuestionIds = student_show_label_ques_ids;
      MatchConfig.mentorShowLabelQuestionIds = mentor_show_label_ques_ids;
      MatchConfig.questionCompatibilityMap = questionCompatibilityMap;
      MatchConfig.setMatchingTypes = setMatchingTypes;
      MatchConfig.confirmConfig(confirmMessage);
      MatchConfig.questionClick(questionCompatibilityMap, setMatchingTypes);
      MatchConfig.addAnotherSet();
      MatchConfig.removeSet();
      MatchConfig.hideMatchingSets();
      MatchConfig.showMatchingSets();
      MatchConfig.showMatchingPrefix();
      MatchConfig.checkQuestionEligibility();
    });
  },

  isCompatibleForDefaultMatching: function(mentorQuestionType, studentQuestionType){
    mentorCompatibleQuestions = MatchConfig.questionCompatibilityMap[mentorQuestionType];
    isCompatible = jQuery.inArray(studentQuestionType, mentorCompatibleQuestions);
    return (isCompatible != -1) ? true : false;
  },

  isCompatibleForSetMatching: function(mentorQuestionType, studentQuestionType){
    return (jQuery.inArray(mentorQuestionType, MatchConfig.setMatchingTypes) != -1 && jQuery.inArray(studentQuestionType, MatchConfig.setMatchingTypes) != -1) ? true : false;
  },

  checkQuestionCompatibility: function(matching_type){
    mentorQuestionType = parseInt(jQuery('option:selected', "#match_config_mentor_question_id").attr('question_type'));
    studentQuestionType = parseInt(jQuery('option:selected', "#match_config_student_question_id").attr('question_type'));
    isCompatible = true;
    if (matching_type  == 0)
      isCompatible = MatchConfig.isCompatibleForDefaultMatching(mentorQuestionType, studentQuestionType);
    else
      isCompatible = MatchConfig.isCompatibleForSetMatching(mentorQuestionType, studentQuestionType);
    if(isCompatible){
      toastr.clear();
      jQuery(".cjs_submit").attr("disabled", false);
    }
    else{
      ChronusValidator.ErrorManager.ShowPageFlash(false, matchConfigValidator.invalidMatchConfig);
      jQuery(".cjs_submit").attr("disabled", true);
    }
    return isCompatible;
  },

  questionClick: function(questionCompatibilityMap, setMatchingTypes){
    jQuery(document).on('change', '.cjs_question', function(){
      matching_type = jQuery(".cjs_matching_type input[name='match_config[matching_type]']:checked").val();
      MatchConfig.checkQuestionCompatibility(matching_type);
      MatchConfig.checkQuestionEligibility();
    });
  },

  hideMatchingSets: function(){
    jQuery(document).on('click', '.cjs_default_radio_button', function(){
      toastr.clear();
      jQuery('.cjs_matching_arena').hide();
    });
  },

  showMatchingSets: function(){
    jQuery(document).on('click', '.cjs_set_matching_radio_button', function(){
      mentorQuestionId = jQuery('#match_config_mentor_question_id').val();
      studentQuestionId = jQuery('#match_config_student_question_id').val();
      matching_type = jQuery(".cjs_matching_type input[name='match_config[matching_type]']:checked").val();
      isCompatible = MatchConfig.checkQuestionCompatibility(matching_type);
      if(isCompatible == true)
        MatchConfig.sendRequestAndPopulate(studentQuestionId, mentorQuestionId);
    });
  },

  showMatchingPrefix: function(){
    jQuery(document).on('click', '.cjs_show_match_label_radio_button', function(){
      jQuery('.cjs_matching_prefix').show();
    });
    jQuery(document).on('click', '.cjs_hide_match_label_radio_button', function(){
      jQuery('.cjs_matching_prefix').hide();
    });
  },

  checkQuestionEligibility: function(){
    mentorQuestionId = jQuery('#match_config_mentor_question_id').val();
    studentQuestionId = jQuery('#match_config_student_question_id').val();
    if (MatchConfig.studentChoiceQuestionIds.indexOf(parseInt(studentQuestionId)) > -1 && MatchConfig.mentorChoiceQuestionIds.indexOf(parseInt(mentorQuestionId)) > -1){
      if (jQuery('.cjs_matching_type').is(':visible') && jQuery('.cjs_set_matching_radio_button').is(":checked")){
        MatchConfig.sendRequestAndPopulate(studentQuestionId, mentorQuestionId);
      }
      else{
        jQuery('.cjs_default_radio_button').prop("checked", true);
        jQuery('.cjs_matching_type').show();
        jQuery('.cjs_show_matching_labels').show();
        jQuery('.cjs_matching_arena').hide();
      }
    }
    else if(MatchConfig.studentShowLabelQuestionIds.indexOf(parseInt(studentQuestionId)) > -1 && MatchConfig.mentorShowLabelQuestionIds.indexOf(parseInt(mentorQuestionId)) > -1){
      jQuery('.cjs_default_radio_button').prop("checked", true);
      jQuery('.cjs_matching_type').hide();
      jQuery('.cjs_show_matching_labels').show();
      jQuery('.cjs_matching_arena').hide();
    }
    else{
      jQuery('.cjs_matching_type').hide();
      jQuery('.cjs_show_matching_labels').hide();
      jQuery('.cjs_default_radio_button').prop("checked", true);
      jQuery('.cjs_matching_arena').hide();
    }
  },

  sendRequestAndPopulate: function(studentQuestionId, mentorQuestionId){
    jQuery('#matching_sets').children(":gt(0)").remove(); 
    jQuery.ajax({
      url: MatchConfig.setMatchingURL,
      data: { config_id: MatchConfig.configId,
              student_ques_id: studentQuestionId,
              mentor_ques_id: mentorQuestionId },
      success: function(response){
        studentChoicesForDisplay = MatchConfig.studentChoices = response["student"];
        MatchConfig.mentorChoices = response["mentor"];
        mentorChoicesForDisplay = [];
        copyForClone = jQuery('.cjs_for_copy');
        if (response["setMapping"])
        {
          studentChoicesForDisplay = Object.keys(response["setMapping"]);
          mentorChoicesForDisplay = studentChoicesForDisplay.map(function(key) {
                                      return response["setMapping"][key];
                                    });
        }
        studentChoicesSize = studentChoicesForDisplay.length;
        for(var i = 0; i < studentChoicesSize; i++) {
          var multiMentorChoiceSets = (mentorChoicesForDisplay[i] || "").split(MatchConfig.multiSetSeparator);
          MatchConfig.populateMenteeandMentorBoxes(multiMentorChoiceSets, studentChoicesForDisplay[i], i);
        }
        MatchConfig.nextIdOfSet = i;
      }
    });
    jQuery('.cjs_matching_arena').show();
  },

  populateMenteeandMentorBoxes: function(multiMentorChoiceSets, curentStudentChoices, outerIndex){
    multiMentorChoiceSets.forEach(function(mentorChoices, index) {
      cloneCopy = copyForClone.clone();
      cloneCopy.removeClass('cjs_for_copy hide');
      MatchConfig.populateMenteeBox(cloneCopy, ("mentee_choice_box_" + outerIndex + "_" + index), curentStudentChoices);
      MatchConfig.populateMentorBox(cloneCopy, ("mentor_choice_box_" + outerIndex + "_" + index), mentorChoices);
      jQuery('#matching_sets').append(cloneCopy);
    });
  },

  populateMenteeBox: function(cloneCopy, menteeBoxId, value){
    menteeBox = cloneCopy.find('.cjs_mentee_selectbox');
    menteeBox.attr("id", menteeBoxId);
    menteeBox.attr("name", "match_config[mentee_choice][]");
    menteeBox.val(value);
    menteeBox.select2({
      multiple: true,
      tags: MatchConfig.studentChoices,
      separator: MatchConfig.select2Separator,
      tokenSeparators: MatchConfig.select2TokenSeparator
    });
    cloneCopy.find('.cjs_mentee_label').attr("for", menteeBoxId);
  },

  populateMentorBox: function(cloneCopy, mentorBoxId, value){
    mentorBox = cloneCopy.find('.cjs_mentor_selectbox');
    mentorBox.attr("id", mentorBoxId);
    mentorBox.attr("name", "match_config[mentor_choices][]");
    mentorBox.val(value);
    mentorBox.select2({
      multiple: true,
      tags: MatchConfig.mentorChoices,
      separator: MatchConfig.select2Separator,
      tokenSeparators: MatchConfig.select2TokenSeparator
    });
    cloneCopy.find('.cjs_mentor_label').attr("for", mentorBoxId);
  },

  addAnotherSet: function(){
    jQuery(document).on('click', '.cjs_add_another_set', function(){
      cloneCopy = jQuery('.cjs_for_copy').clone();
      cloneCopy.removeClass('cjs_for_copy hide');
      i = MatchConfig.nextIdOfSet;
      MatchConfig.nextIdOfSet = i+1;
      MatchConfig.populateMenteeBox(cloneCopy, ("mentee_choice_box_" + i), "");
      MatchConfig.populateMentorBox(cloneCopy, ("mentor_choice_box_" + i), "");
      jQuery('#matching_sets').append(cloneCopy);
    });
  },

  removeSet: function(){
    jQuery(document).on('click', '.cjs_remove_set', function(){
      jQuery(this).parent().parent().parent().remove();
    });
  },

  confirmConfig: function(confirmMsg){
    jQuery(document).on('click', '.cjs_submit', function(event){
      if (jQuery('.cjs_set_matching_radio_button').is(":checked"))
      {
        var notMappedChoices = MatchConfig.studentChoices.slice();
        jQuery('input.cjs_mentee_selectbox:visible').each(function(){
          var menteeChoices = jQuery(this).val().split(MatchConfig.select2Separator);
          menteeChoices.forEach(function(choice){
            var index = notMappedChoices.indexOf(choice);
            if (index != -1){
              notMappedChoices.splice(index, 1);
            }
          });
        });
        if (notMappedChoices.length > 0)
        {
          event.preventDefault();
          var quoteNotMappedChoices = notMappedChoices.map(function(item) { return "'" + item + "'"; });
          var message = confirmMsg + "<br/>" + quoteNotMappedChoices;
          chronusConfirm(message, function(){
            jQuery(".cjs_match_config_form").submit();
          });
        }
      }
    });
  }
}