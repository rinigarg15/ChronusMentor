var myApp = angular.module('bulkMatch',[]);
var itemsToDisplay = 10;

myApp.directive('scrollPosition', function($window) {
  return function(scope, element, attrs) {
    var windowElement = angular.element($window);
    var students = scope.students;
    windowElement.on('scroll', function() {
      if (angular.element($window).scrollTop() >= (angular.element(document).height() - angular.element($window).height()-10)){
        scope.$apply(function() {
            scope.display_limit = scope.display_limit+itemsToDisplay;
        });
      }
    });
  }
});

myApp.directive('innerScrollPosition', function() {
  return function(scope, element, attrs) {
    var divId = "#search_text_results_" + (scope.isMenteeToMentorMatch() ? scope.student.id : scope.mentor.id);
    angular.element(".cjs-content-area").on('scroll', function(event) {
      if(event.handled !== true) {
        if ((angular.element(divId).scrollTop() + angular.element(divId).innerHeight()) >= angular.element(divId)[0].scrollHeight){
          scope.$apply(function() {
            if(scope.isMenteeToMentorMatch()){
              scope.student.suggested_mentors_length = scope.student.suggested_mentors_length + itemsToDisplay;
            }
            else{
              scope.mentor.suggested_students_length = scope.mentor.suggested_students_length + itemsToDisplay;
            }
          });
        }
        event.handled = true;
      }
    });
  }
});

function BulkMatchCtrl($scope, $http, $timeout){
  $scope.students = BulkMatch.students;
  $scope.mentors = BulkMatch.mentors;
  $scope.bulk_match_vars = BulkMatch.bulk_match_vars;
  $scope.mentors_hash = {};
  $scope.students_hash = {};
  $scope.unmatched_label = BulkMatch.locale.unMatched;
  $scope.unavailable_label = BulkMatch.locale.notAvailable;
  $scope.selected_label = BulkMatch.locale.selected;
  $scope.drafted_label = BulkMatch.locale.drafted;
  $scope.published_label = BulkMatch.locale[$scope.bulk_match_vars.type].published;
  $scope.scores = [];
  $scope.display_limit = itemsToDisplay;
  $scope.recommendMentors = $scope.bulk_match_vars.recommend_mentors;
  $scope.naString = BulkMatch.locale.NA;
  $scope.mentorLists = {
    drafted: "drafted_mentors_html",
    connected: "connected_mentors_html"
  }
  $scope.studentLists = {
    drafted: "drafted_students_html",
    connected: "connected_students_html"
  }
  /*
    Hash where key is student_id and value is a hash with mentor_ids as keys and necessary info as hash
    Ex :

    studentMentorMap = {
      student_id: {
        mentor_id1: {
          score: value,
          selected: value
        }
      },
      student_id2 : {
        mentor_id1: { .. }
      }
    }

  */
  $scope.studentMentorMap = {};
  $scope.mentorStudentMap = {};

  $scope.isMenteeToMentorMatch = function(){
    return $scope.bulk_match_vars.orientation_type == BulkMatch.menteeOrientationType
  };

  $scope.isMentorToMenteeMatch = function(){
    return !$scope.isMenteeToMentorMatch()
  };

  $scope.populateMentorsHash = function(){
    angular.forEach($scope.mentors, function(mentor) {
      $scope.mentors_hash[mentor.id] = mentor;
    });
  };

  $scope.populateStudentsHash = function(){
    angular.forEach($scope.students, function(student) {
      $scope.students_hash[student.id] = student;
    });
  };
  $scope.populateMentorsHash();
  $scope.populateStudentsHash();

  $scope.updateSuggestedMentorsAndStudentMentorMap = function(){
    angular.forEach($scope.students, function(student) {
      angular.forEach(student.suggested_mentors, function(mentor){
        mentor.push($scope.mentors_hash[mentor[0]].name);
        $scope.studentMentorMap[student.id] = $scope.studentMentorMap[student.id] || {};
        $scope.studentMentorMap[student.id][mentor[0]] = {
          score: mentor[1],
          selected: -1
        }
      });
      if(student.selected_mentors && student.selected_mentors.length > 0) {
        student.best_mentor_score = $scope.studentMentorMap[student.id][student.selected_mentors[0]].score;
      }
      else {
        student.best_mentor_score = 0
      }
      student.current_best_mentor_score = student.best_mentor_score;
    });
  };

  $scope.updateSuggestedStudentsAndMentorStudentMap = function(){
    angular.forEach($scope.mentors, function(mentor) {
      angular.forEach(mentor.suggested_students, function(student){
        student.push($scope.students_hash[student[0]].name);
        $scope.mentorStudentMap[mentor.id] = $scope.mentorStudentMap[mentor.id] || {};
        $scope.mentorStudentMap[mentor.id][student[0]] = {
          score: student[1],
          selected: -1
        }
      });
      if(mentor.selected_students && mentor.selected_students.length > 0) {
        mentor.best_mentor_score = $scope.mentorStudentMap[mentor.id][mentor.selected_students[0]].score;
      }
      else {
        mentor.best_mentor_score = 0
      }
      mentor.current_best_mentor_score = mentor.best_mentor_score;
    });
  };
  $scope.isMenteeToMentorMatch() ? $scope.updateSuggestedMentorsAndStudentMentorMap() : $scope.updateSuggestedStudentsAndMentorStudentMap();

  $scope.getStudent = function(studentId){
    var student_record = '';
    angular.forEach($scope.students, function(student) {
      if(student.id == studentId){
        student_record = student
        return student_record;
      }
    });
    return student_record;
  };

  $scope.getMentor = function(mentorId){
    var mentor_record = '';
    angular.forEach($scope.mentors, function(mentor) {
      if(mentor.id == mentorId){
        mentor_record = mentor
        return mentor_record;
      }
    });
    return mentor_record;
  };

  $scope.getMatchPerformanceMetrics = function(){
    $scope.scores = [];
    if($scope.isMenteeToMentorMatch()){
      angular.forEach($scope.students, function(student) {
        angular.forEach(student.selected_mentors, function(mentorId) {
          $scope.scores.push($scope.studentMentorMap[student.id][mentorId].score);
        });
      });
    }
    else{
      angular.forEach($scope.mentors, function(mentor) {
        angular.forEach(mentor.selected_students, function(studentId) {
          $scope.scores.push($scope.mentorStudentMap[mentor.id][studentId].score);
        });
      });
    }
    $scope.updatePerformanceMetrics();
  };

  $scope.updatePerformanceMetrics = function(){
    if($scope.scores.length == 0) {
      return null;
    }
    var sumScores = 0;
    angular.forEach($scope.scores, function(score) {
      sumScores += score;
    });
    minScore = $scope.scores.min();
    maxScore = $scope.scores.max();
    averageScore = (sumScores/$scope.scores.length).toFixed(2);
    deviation = $scope.computeDeviationScore(averageScore);

    $scope.bulk_match_vars.average_score = averageScore + ' %';
    $scope.bulk_match_vars.deviation = deviation + ' %';
    $scope.bulk_match_vars.range = minScore + ' % - ' + maxScore + ' %';
  };

  $scope.computeDeviationScore = function(averageScore){
    var sumforVariance = 0;
    var varianceScore = 0;
    for(var i = 0; i < $scope.scores.length; i++){
      sumforVariance = sumforVariance+Math.pow(($scope.scores[i]-averageScore), 2);
    }
    if($scope.scores.length > 1){
      varianceScore = sumforVariance/($scope.scores.length-1);
    }
    var deviationScore = Math.sqrt(varianceScore).toFixed(2);
    return deviationScore;
  };

  $scope.updateSelectedMentor = function(student, mentorId){
    var newMentor = $scope.mentors_hash[mentorId];
    if(student.group_status == $scope.drafted_label){
      alert(BulkMatch.locale[$scope.bulk_match_vars.type].updateDrafted);
    }
    else if(student.id == mentorId){
      alert(BulkMatch.locale[$scope.bulk_match_vars.type].connectSamePerson);
    }
    else if(student.selected_mentors.indexOf(mentorId) > -1) {
      alert(BulkMatch.locale.mentorAlreadySelected);
    }
    else if($scope.recommendMentors && student.selected_count == $scope.bulk_match_vars.max_suggestion_count) {
      alert(BulkMatch.locale.BulkRecommendation.removeMentor);
    }
    else if(newMentor.mentor_prefer_one_time_mentoring_and_program_allowing){
      alert(BulkMatch.locale.oneTimeMentoring);
    }
    else {
      if(newMentor.slots_available > 0) {
        if(newMentor.pickable_slots > 0) {
          $scope.removeMentorInMatching(student);
          $scope.updateSelectedMentorCallbacks(student, newMentor);
        }
        else {
          $scope.alterPickableSlots(student.id, mentorId);
        }
      }
      else {
        if($scope.getStudentsToAlterFor(mentorId).length > 0){
          $scope.alterPickableSlots(student.id, mentorId);
        }
        else {
          alert(BulkMatch.locale.noSlotsAvailable);
        }
      }
    }
  };

  $scope.updateSelectedStudent = function(mentor, studentId){
    var newStudent = $scope.students_hash[studentId];
    if(mentor.id == studentId){
      alert(BulkMatch.locale[$scope.bulk_match_vars.type].connectSamePerson);
    }
    else if(mentor.selected_students.indexOf(studentId) > -1) {
      alert(BulkMatch.locale.studentAlreadySelected);
    }
    else {
      if(newStudent.pickable_slots > 0){
        $scope.removeStudentInMatching(mentor);
        $scope.updateSelectedStudentCallbacks(mentor, newStudent);
      }
      else{
        $scope.alterPickableSlots(studentId, mentor.id);
      }
    }
  };

  $scope.removeMentorInMatching= function(student){
    if(!$scope.recommendMentors && student.selected_count != 0) {
      $scope.removeSelectedMentor(student, student.selected_mentors[0]);
    }
  };

  $scope.removeSelectedMentor = function(student, mentorId) {
    index = student.selected_mentors.indexOf(mentorId);
    student.selected_mentors.splice(index, 1);
    student.selected_count--;
    $scope.updateCurrentBestMentorScore(student, mentorId, false);
    $scope.studentMentorMap[student.id][mentorId].selected = false;
    $scope.mentors_hash[mentorId].pickable_slots++;
    $scope.mentors_hash[mentorId].recommended_count--;
    if(student.selected_count == 0) {
      student.group_status = $scope.unmatched_label;
      student.highlight = false;
      student.selected_for_bulk = false;
    }
    $scope.getMatchPerformanceMetrics();
  }

  $scope.removeStudentInMatching= function(mentor){
    if(mentor.selected_count != 0) {
      $scope.removeSelectedStudent(mentor, mentor.selected_students[0]);
    }
  };

  $scope.removeSelectedStudent = function(mentor, studentId) {
    index = mentor.selected_students.indexOf(studentId);
    mentor.selected_students.splice(index, 1);
    mentor.selected_count--;
    $scope.updateCurrentBestStudentScore(mentor, studentId, false);
    $scope.mentorStudentMap[mentor.id][studentId].selected = false;
    $scope.students_hash[studentId].pickable_slots++;
    if(mentor.selected_count == 0) {
      mentor.group_status = $scope.unmatched_label;
      mentor.highlight = false;
      mentor.selected_for_bulk = false;
    }
    $scope.getMatchPerformanceMetrics();
  }

  $scope.doesMentorIdNameMatch = function(mentorId, str, undefinedmentorIdReturnValue) {
    if(typeof(mentorId) === "undefined") return getDefaultVal(undefinedmentorIdReturnValue, (getDefaultVal(str, "").length == 0));
    return ($scope.mentors_hash[mentorId]['name'].toLowerCase().indexOf(getDefaultVal(str, "").toLowerCase()) !== -1);
  }

  $scope.doesStudentIdNameMatch = function(studentId, str, undefinedStudentIdReturnValue) {
    if(typeof(studentId) === "undefined") return getDefaultVal(undefinedmentorIdReturnValue, (getDefaultVal(str, "").length == 0));
    return ($scope.students_hash[studentId]['name'].toLowerCase().indexOf(getDefaultVal(str, "").toLowerCase()) !== -1);
  }

  $scope.doesMentorIdsNameMatch = function(mentorIds, str) {
    if(getDefaultVal(str, "").length == 0) return true;
    return (mentorIds.filter(function(mentorId){ return $scope.doesMentorIdNameMatch(mentorId, str) }).length > 0);
  }

  $scope.doesStudentIdsNameMatch = function(studentIds, str) {
    if(getDefaultVal(str, "").length == 0) return true;
    return (studentIds.filter(function(studentId){ return $scope.doesStudentIdNameMatch(studentId, str) }).length > 0);
  }

  $scope.mentorNameSearcher = function(student) {
    return $scope.doesMentorIdsNameMatch(student.selected_mentors, $scope.mentorNameSearch);
  }

  $scope.menteeNameSearcher = function(mentor) {
    return $scope.doesStudentIdsNameMatch(mentor.selected_students, $scope.menteeNameSearch);
  }

  $scope.mentorName = function(user) {
    if($scope.isMenteeToMentorMatch()){
      var mentorId = user.selected_mentors[0];
      if(typeof(mentorId) === "undefined") return '';
      return $scope.mentors_hash[mentorId]['name'];
    }
    else{
      return user.name
    }
  }

  $scope.studentName = function(mentor) {
    var studentId = mentor.selected_students[0];
    if(typeof(studentId) === "undefined") return '';
    return $scope.students_hash[studentId]['name'];
  }

  $scope.getStudentsToAlterFor = function(mentorId){
    var studentsToAlter = [];
    angular.forEach($scope.students, function(student) {
      if(student.selected_mentors.indexOf(mentorId) > -1){
        studentsToAlter.push(student);
      }
    });
    return studentsToAlter;
  };

  $scope.getMentorsToAlterFor = function(studentId){
    var mentorsToAlter = [];
    angular.forEach($scope.mentors, function(mentor) {
      if(mentor.selected_students.indexOf(studentId) > -1){
        mentorsToAlter.push(mentor);
      }
    });
    return mentorsToAlter;
  };

  $scope.initializeAlterPickableSlotsPopupParams = function(mentorId, studentId, orientationType){
    if($scope.isMenteeToMentorMatch()){
      $scope.mentorId = mentorId; 
      $scope.users_to_alter = $scope.getStudentsToAlterFor(mentorId);
    }
    else{
      $scope.studentId = studentId; 
      $scope.users_to_alter = $scope.getMentorsToAlterFor(studentId);
    }
  };

  $scope.alterUser = function(mentorId, studentId, existingUserId){
    var existingUserRecord = $scope.isMenteeToMentorMatch() ? $scope.getStudent(existingUserId) : $scope.getMentor(existingUserId);;
    if(existingUserRecord.group_status == $scope.drafted_label){
      $scope.discardRequest(existingUserRecord, studentId, mentorId);
    }
    else{
      $scope.isMenteeToMentorMatch() ? $scope.alterStudentCallbacks(mentorId, studentId, existingUserRecord) : $scope.alterMentorCallbacks(mentorId, studentId, existingUserRecord);
    }
  };

  $scope.alterStudentCallbacks = function(mentorId, studentId, existingStudentRecord){
    var mentorRecordToAlter = $scope.mentors_hash[mentorId];
    var newStudentRecord = $scope.getStudent(studentId);
    $scope.removeSelectedMentor(existingStudentRecord, mentorId)
    newStudentRecord.highlight = jQuery('#master_checkbox').is(':checked');
    newStudentRecord.selected_for_bulk = newStudentRecord.highlight;
    $scope.removeMentorInMatching(newStudentRecord);
    $scope.updateSelectedMentorCallbacks(newStudentRecord, mentorRecordToAlter);
    $scope.getMatchPerformanceMetrics();
    closeQtip();
    $scope.refreshView(100);
  };

  $scope.alterMentorCallbacks = function(mentorId, studentId, existingMentorRecord){
    var studentRecordToAlter = $scope.students_hash[studentId];
    var newMentorRecord = $scope.getMentor(mentorId);
    $scope.removeSelectedStudent(existingMentorRecord, studentId)
    newMentorRecord.highlight = jQuery('#master_checkbox').is(':checked');
    newMentorRecord.selected_for_bulk = newMentorRecord.highlight;
    $scope.removeStudentInMatching(newMentorRecord);
    $scope.updateSelectedStudentCallbacks(newMentorRecord, studentRecordToAlter);
    $scope.getMatchPerformanceMetrics();
    closeQtip();
    $scope.refreshView(100);
  };

  $scope.getAlterUserLabel = function(userId){
    var userToAlter = $scope.isMenteeToMentorMatch() ? $scope.getStudent(userId) : $scope.getMentor(userId);
    if(userToAlter.group_status == $scope.selected_label){
      return BulkMatch.locale[$scope.bulk_match_vars.type].removeMatch;
    }
    else if(userToAlter.group_status == $scope.drafted_label){
      return BulkMatch.locale[$scope.bulk_match_vars.type].removeDraftConnection;
    }
    else{
      return '-';
    }
  };

  $scope.updateCurrentBestMentorScore = function(student, mentorId, addition) {
    if(addition && student.current_best_mentor_score < $scope.studentMentorMap[student.id][mentorId].score) {
      student.current_best_mentor_score = $scope.studentMentorMap[student.id][mentorId].score;
    }
    else if(!addition && student.current_best_mentor_score == $scope.studentMentorMap[student.id][mentorId].score) {
      student.current_best_mentor_score = 0;
      angular.forEach(student.selected_mentors, function(selectedMentorId) {
        var selectedMentorScore = $scope.studentMentorMap[student.id][selectedMentorId].score;
        if(student.current_best_mentor_score < selectedMentorScore) {
          student.current_best_mentor_score = selectedMentorScore;
        }
      });
    }
  }

  $scope.updateCurrentBestStudentScore = function(mentor, studentId, addition) {
    if(addition && mentor.current_best_mentor_score < $scope.mentorStudentMap[mentor.id][studentId].score) {
      mentor.current_best_mentor_score = $scope.mentorStudentMap[mentor.id][studentId].score;
    }
    else if(!addition && mentor.current_best_mentor_score == $scope.mentorStudentMap[mentor.id][studentId].score) {
      mentor.current_best_mentor_score = 0;
      angular.forEach(mentor.selected_students, function(selectedStudentId) {
        var selectedStudentScore = $scope.mentorStudentMap[mentor.id][selectedStudentId].score;
        if(mentor.current_best_mentor_score < selectedStudentScore) {
          mentor.current_best_mentor_score = selectedStudentScore;
        }
      });
    }
  }

  $scope.updateSelectedMentorCallbacks = function(student, mentorObj){
    mentorObj.pickable_slots--;
    mentorObj.recommended_count++;
    student.selected_mentors.push(mentorObj.id);
    student.selected_count++;
    $scope.updateCurrentBestMentorScore(student, mentorObj.id, true);
    $scope.studentMentorMap[student.id][mentorObj.id].selected = true;
    student.group_status = $scope.selected_label;
    student.primary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].draftMatch;
    student.secondary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].publish;
    student.show_summary_details = false;
    $scope.getMatchPerformanceMetrics();
  };

  $scope.updateSelectedStudentCallbacks = function(mentor, studentObj){
    studentObj.recommended_count++;
    studentObj.pickable_slots--;
    mentor.selected_students.push(studentObj.id);
    mentor.selected_count++;
    $scope.updateCurrentBestStudentScore(mentor, studentObj.id, true);
    $scope.mentorStudentMap[mentor.id][studentObj.id].selected = true;
    mentor.group_status = $scope.selected_label;
    mentor.primary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].draftMatch;
    mentor.secondary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].publish;
    mentor.show_summary_details = false;
    $scope.getMatchPerformanceMetrics();
  };

  $scope.canSelectMentor = function(student, mentorId) {
    if($scope.studentMentorMap[student.id][mentorId].selected == -1) {
      $scope.studentMentorMap[student.id][mentorId].selected = (student.selected_mentors.indexOf(mentorId) > -1);
    }
    return (!$scope.studentMentorMap[student.id][mentorId].selected && $scope.mentors_hash[mentorId].pickable_slots > 0);
  };

  $scope.canSelectStudent = function(mentor, studentId) {
    if($scope.mentorStudentMap[mentor.id][studentId].selected == -1) {
      $scope.mentorStudentMap[mentor.id][studentId].selected = (mentor.selected_students.indexOf(studentId) > -1);
    }
    return (!$scope.mentorStudentMap[mentor.id][studentId].selected && $scope.students_hash[studentId].pickable_slots > 0);
  };

  $scope.alterPickableSlots = function(studentId, mentorId){
    var dataParameters = {student_id: studentId, mentor_id: mentorId, orientation_type: $scope.bulk_match_vars.orientation_type};
    jQueryShowQtip('#cjs_bulk_match_result', 600, $scope.bulk_match_vars.alter_pickable_slots_path, dataParameters, {method: "get", modal: true});
  };

  $scope.getSuggestedItemClass = function(student, mentor_id){
    var baseClass = 'cui-content-area-item';
    if(student.selected_mentors.indexOf(mentor_id) > -1) {
      return baseClass + ' text-muted gray-bg';
    }
    else{
      var mentorForClass = $scope.mentors_hash[mentor_id];
      if(mentorForClass.pickable_slots <= 0 || mentorForClass.mentor_prefer_one_time_mentoring_and_program_allowing) {
        return baseClass + ' text-muted';
      }
      else{
        return baseClass;
      }
    }
  };

  $scope.getSuggestedMenteeClass = function(mentor, student_id){
    if(mentor.selected_students.indexOf(student_id) > -1) {
      return 'text-muted gray-bg';
    }
  };

  $scope.updateMenteeToMentorPairStatus = function(student, actionType) {
    if(student.selected_mentors.indexOf(student.id) > -1) {
      alert(BulkMatch.locale[$scope.bulk_match_vars.type].connectSamePerson);
    } else if(student.group_status == $scope.selected_label && actionType == "primary") {
      if($scope.bulk_match_vars.request_notes) {
        // Will always be false for BulkRecommendation
        $scope.fetchMenteeToMentorNotes(student, $scope.bulk_match_vars.update_type.draft);
      } else if(!$scope.recommendMentors) {
        $http({
          method: "GET",
          url: $scope.bulk_match_vars.groups_alert_path,
          params: { student_id: student.id, mentor_id_list: student.selected_mentors.join(","), update_type: $scope.bulk_match_vars.update_type.draft }
        }).success(function(data) {
          if(data.groups_alert) {
            BulkMatch.showGroupsAlert(data.groups_alert);
          } else {
            $scope.draftRequest(student);
          }
        });
      } else {
        $scope.draftRequest(student);
      }
    } else if((student.group_status == $scope.selected_label && actionType == "secondary") || (student.group_status == $scope.drafted_label && actionType == "primary")) {
      if($scope.recommendMentors) {
        chronusConfirm(BulkMatch.locale.publishConfirmation, function() { $scope.publishRequest(student); });
      } else {
        $scope.fetchMenteeToMentorNotes(student, $scope.bulk_match_vars.update_type.publish);
      }
    } else if(student.group_status == $scope.drafted_label && actionType == "secondary") {
      $scope.discardRequest(student, 0);
    } else if(student.group_status == $scope.published_label && actionType == "primary" && $scope.recommendMentors) {
      $scope.discardRequest(student, 0);
    }
  };

  $scope.updateMentorToMenteePairStatus = function(mentor, actionType) {
    if(mentor.selected_students.indexOf(mentor.id) > -1) {
      alert(BulkMatch.locale[$scope.bulk_match_vars.type].connectSamePerson);
    }else if(mentor.group_status == $scope.selected_label && actionType == "primary") {
      if($scope.bulk_match_vars.request_notes) {
        // Will always be false for BulkRecommendation
         $scope.fetchMentorToMenteeNotes(mentor, $scope.bulk_match_vars.update_type.draft);
      }else {
        $http({
          method: "GET",
          url: $scope.bulk_match_vars.groups_alert_path,
          params: { mentor_id: mentor.id, student_id_list: mentor.selected_students.join(","), update_type: $scope.bulk_match_vars.update_type.draft }
        }).success(function(data) {
          if(data.groups_alert) {
            BulkMatch.showGroupsAlert(data.groups_alert);
          } else {
            $scope.draftRequest(mentor);
          }
        });
      }
    }else if((mentor.group_status == $scope.selected_label && actionType == "secondary") || (mentor.group_status == $scope.drafted_label && actionType == "primary")) {
      $scope.fetchMentorToMenteeNotes(mentor, $scope.bulk_match_vars.update_type.publish);
    }else if(mentor.group_status == $scope.drafted_label && actionType == "secondary") {
      $scope.discardRequest(mentor, 0);
    }
  };

  $scope.postBulkUpdatePairStatus = function(actionType, userObjects, studentMentorMap, updateType, mentoringModelId) {
    var message = jQuery("#cjs_bulk_message").val();
    var loaderImg = jQuery("#loading_results");
    var token = jQuery("meta[name='csrf-token']").attr("content");
    var groupIds = $scope.getGroupIds(userObjects);

    closeQtip();
    jQuery("#cjs_bulk_match_groups_alert_modal").modal("hide");

    loaderImg.show();
    disableBulkMatchDivContents(true);
    $http.post(
      $scope.bulk_match_vars.bulk_update_status_path,
      { update_type: actionType, group_ids: groupIds, student_mentor_map: studentMentorMap, message: message, mentoring_model_id: mentoringModelId, orientation_type: $scope.bulk_match_vars.orientation_type },
      { headers: { 'X-CSRF-Token': token } }
    ).success(function(data) {
      if(data.error_flash) {
        alert(data.error_flash);
      } else if(actionType == updateType.discard) {
        alert(BulkMatch.locale[$scope.bulk_match_vars.type].discardedSuccess);
        $scope.discardCallback(userObjects);
      } else if(actionType == updateType.publish) {
        if($scope.bulk_match_vars.show_published) {
          alert(BulkMatch.locale[$scope.bulk_match_vars.type].publishedSuccess);
        } else {
          alert(BulkMatch.locale[$scope.bulk_match_vars.type].publishedSuccessChangeSettings);
        }
        $scope.publishCallback(userObjects, data.object_id_group_id_map);
      } else if(actionType == updateType.draft) {
        alert(BulkMatch.locale[$scope.bulk_match_vars.type].draftedSuccess);
        $scope.draftCallback(userObjects, data.object_id_group_id_map);
      }
      bulkActionEnableActions();
    });
  };

  function bulkActionEnableActions(){
    jQuery("div#loading_results").hide();
    disableBulkMatchDivContents(false);
  };

  function disableBulkMatchDivContents(disable) {
    var element = jQuery('.cui_bulk_match_top_banner > .cjs_bulk_actions').find('*');
    disable ? element.addClass("disabled") : element.removeClass("disabled")
    jQuery("#cjs_refresh_results").prop("disabled", disable);
  };

  $scope.getBulkUpdateObjects = function(statusLabel){
    var userObjects = $scope.isMenteeToMentorMatch() ? $scope.selectedStudentsWithGroupStatus(statusLabel) : $scope.selectedMentorsWithGroupStatus(statusLabel);
    return userObjects;
  };

  $scope.bulkUpdatePairStatus = function(actionType, showPopup) {
    var updateType = $scope.bulk_match_vars.update_type;
    var statusLabel = (actionType == updateType.draft ? $scope.selected_label : $scope.drafted_label);
    var userObjects = $scope.getBulkUpdateObjects(statusLabel)
    var studentMentorMap = $scope.getStudentMentorMapFor(userObjects);
    var groupIds = $scope.getGroupIds(userObjects);
    if(userObjects.length > 0) {
      if(showPopup) {
        if(actionType == updateType.publish) {
          jQueryShowQtip(null, null, $scope.bulk_match_vars.fetch_notes_path, { action_type: actionType, bulk_action: true, group_ids: groupIds, orientation_type: $scope.bulk_match_vars.orientation_type }, { method: "get", modal: true } );
          return false;
        } else if(actionType == updateType.draft) {
          jQuery.ajax({
            method: "GET",
            dataType: "json",
            url: $scope.bulk_match_vars.groups_alert_path,
            data: { bulk_action: true, student_mentor_map: studentMentorMap, update_type: updateType.draft, orientation_type: $scope.bulk_match_vars.orientation_type }
          }).success(function(data) {
            if(data.groups_alert) {
              BulkMatch.showGroupsAlert(data.groups_alert);
            } else {
              $scope.postBulkUpdatePairStatus(actionType, userObjects, studentMentorMap, updateType);
            }
          });
        }
      } else {
        if(actionType == updateType.publish) {
          var mentoringModelId = jQuery("#cjs_assign_mentoring_model").val();
          chronusConfirm(
            BulkMatch.locale.publishConfirmation,
            function() { $scope.postBulkUpdatePairStatus(actionType, userObjects, studentMentorMap, updateType, mentoringModelId); },
            function() { bulkActionEnableActions(); }
          );
        } else {
          $scope.postBulkUpdatePairStatus(actionType, userObjects, studentMentorMap, updateType);
        }
      }
    } else {
      if(actionType == updateType.draft) {
        alert(BulkMatch.locale[BulkMatch.type].selectPairError);
      } else {
        alert(BulkMatch.locale[BulkMatch.type].selectDraftedRecordError);
      }
    }
  };

  $scope.getObjectSpecificParams = function(userObject){
    var objectSpecificParams = $scope.isMenteeToMentorMatch() ? {student_id: userObject.id, mentor_id_list: userObject.selected_mentors.join(",")} : {mentor_id: userObject.id, student_id_list: userObject.selected_students.join(",")};
    return objectSpecificParams
  };

  $scope.draftRequest = function(userObject, form) {
    var loaderImg = jQuery("#loading_results");
    loaderImg.show();
    var objectSpecificParams = $scope.getObjectSpecificParams(userObject);
    var defaultOptions = {notes: userObject.notes, message: userObject.message, request_notes: $scope.bulk_match_vars.request_notes, update_type: $scope.bulk_match_vars.update_type.draft, orientation_type: $scope.bulk_match_vars.orientation_type }
    var params = jQuery.extend({}, defaultOptions, objectSpecificParams);
    $http({
      method: 'GET',
      url: $scope.bulk_match_vars.update_status_path,
      params: params
    }).success(function(data) {
      closeQtip();
      jQuery("#cjs_bulk_match_groups_alert_modal").modal("hide");
      if(data.error_flash) {
        alert(data.error_flash);
      } else {
        if(!$scope.bulk_match_vars.show_drafted) {
          alert(BulkMatch.locale[$scope.bulk_match_vars.type].draftedSuccessChangeSettings);
        }
        $scope.draftCallback([userObject], data.object_id_group_id_map);
      }
      if(form) {
        jQuery.rails.enableFormElements(form);
      }
      loaderImg.hide();
    });
  };


  $scope.publishRequest = function(userObject, form, mentoringModelId, groupName) {
    var loaderImg = jQuery("#loading_results");
    loaderImg.show();
    var objectSpecificParams = $scope.getObjectSpecificParams(userObject);
    var defaultOptions = {notes: userObject.notes, message: userObject.message, request_notes: $scope.bulk_match_vars.request_notes, update_type: $scope.bulk_match_vars.update_type.publish, group_id: userObject.group_id, group_name: groupName, mentoring_model_id: mentoringModelId, orientation_type: $scope.bulk_match_vars.orientation_type }
    var params = jQuery.extend({}, defaultOptions, objectSpecificParams);
    $http({
      method: 'GET',
      url: $scope.bulk_match_vars.update_status_path,
      params: params 
    }).success(function(data) {
      closeQtip();
      if(data.error_flash) {
        alert(data.error_flash);
      } else {
        if(!$scope.bulk_match_vars.show_published) {
          alert(BulkMatch.locale[$scope.bulk_match_vars.type].publishedSuccessChangeSettings);
        }
        $scope.publishCallback([userObject], data.object_id_group_id_map);
      }
      if(form) {
        jQuery.rails.enableFormElements(form);
      }
      loaderImg.hide();
    });
  };

  $scope.discardRequest = function(userObject, alterStudentId, selectedMentorId) {
    var loaderImg = jQuery("#loading_results");
    var objectSpecificParams = $scope.getObjectSpecificParams(userObject);
    var defaultOptions = {update_type: $scope.bulk_match_vars.update_type.discard, group_id: userObject.group_id, orientation_type: $scope.bulk_match_vars.orientation_type }
    var params = jQuery.extend({}, defaultOptions, objectSpecificParams);
    loaderImg.show();
    $http({
      method: 'GET',
      url: $scope.bulk_match_vars.update_status_path,
      params: params
    }).success(function(data){
      if(data.error_flash){
        alert(data.error_flash);
      }
      else{
        $scope.discardCallback([userObject]);
        if(alterStudentId != 0){
          $scope.isMenteeToMentorMatch() ? $scope.alterStudentCallbacks(selectedMentorId, alterStudentId, userObject) : $scope.alterMentorCallbacks(selectedMentorId, alterStudentId, userObject);
        }
      }
      loaderImg.hide();
    });
  };

  $scope.draftCallback = function(userObjects, objectIdGroupIdMap) {
    objectIdGroupIdMap = objectIdGroupIdMap || {};
    angular.forEach(userObjects, function(userObject) {
      groupId = objectIdGroupIdMap[userObject.id];
      if(groupId || $scope.recommendMentors) {
        userObject.group_status = $scope.drafted_label;
        userObject.primary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].publish;
        userObject.secondary_action_label = BulkMatch.locale.discardDraft;
        userObject.highlight = jQuery('#cjs_bulk_match_record_'+userObject.id).is(':checked') || jQuery('#master_checkbox').is(':checked');
        userObject.selected_for_bulk = userObject.highlight;
        userObject.group_id = groupId;
        if(!$scope.recommendMentors) {
          if($scope.isMenteeToMentorMatch()){
            $scope.updateMentorList(userObject, $scope.mentorLists.drafted);
          }else{
            $scope.updateMentorListMentorToMentee(userObject, $scope.students_hash[userObject.selected_students[0]], $scope.mentorLists.drafted);
            $scope.updateStudentList(userObject, $scope.studentLists.drafted);
          }
        }
      }
    });
  };

  $scope.publishCallback = function(userObjects, objectIdGroupIdMap) {
    objectIdGroupIdMap = objectIdGroupIdMap || {};
    angular.forEach(userObjects, function(userObject) {
      groupId = objectIdGroupIdMap[userObject.id];
      if(groupId || $scope.recommendMentors) {
        userObject.primary_action_label = BulkMatch.locale.BulkRecommendation.discard;
        userObject.secondary_action_label = '';
        userObject.group_id = groupId;
        if(!$scope.recommendMentors) {
          userObject.primary_action_label = '';
          $scope.updateListsAfterPublish(userObject);
          $scope.removeFromListsAfterPublish(userObject);
        }
        userObject.group_status = $scope.published_label;
        userObject.highlight = false;
        userObject.selected_for_bulk = false;
      }
    });
  };

  $scope.updateListsAfterPublish = function(userObject){
    if($scope.isMenteeToMentorMatch()){
      $scope.updateMentorList(userObject, $scope.mentorLists.connected);
    }else{
      $scope.updateMentorListMentorToMentee(userObject, $scope.students_hash[userObject.selected_students[0]], $scope.mentorLists.connected);
      $scope.updateStudentList(userObject, $scope.studentLists.connected)
    }
  };

  $scope.removeFromListsAfterPublish = function(userObject){
    if(userObject.group_status == $scope.drafted_label) {
      if($scope.isMenteeToMentorMatch()){
        $scope.removeFromDraftedMentorsList(userObject);
      }else{
        $scope.removeFromDraftedMentorsListMentorToMentee(userObject, $scope.students_hash[userObject.selected_students[0]]);
        $scope.removeFromDraftedStudentsList(userObject);
      }
    }
  };

  $scope.discardCallback = function(userObjects) {
    angular.forEach(userObjects, function(userObject) {
      userObject.group_status = $scope.selected_label;
      userObject.primary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].draftMatch;
      userObject.secondary_action_label = BulkMatch.locale[$scope.bulk_match_vars.type].publish;
      userObject.highlight = jQuery('#cjs_bulk_match_record_'+userObject.id).is(':checked') || jQuery('#master_checkbox').is(':checked');
      userObject.selected_for_bulk = userObject.highlight;
      if(!$scope.recommendMentors) {
        if($scope.isMenteeToMentorMatch()){
          $scope.removeFromDraftedMentorsList(userObject);
        }else{
          $scope.removeFromDraftedMentorsListMentorToMentee(userObject, $scope.students_hash[userObject.selected_students[0]]);
          $scope.removeFromDraftedStudentsList(userObject);
        }
      }
      userObject.group_id = null;
    });
  };

  $scope.removeFromDraftedMentorsListMentorToMentee = function(mentor, student) {
    var newDraftedMentorsHtml = "";

    BulkMatch.UserIdGroupIdList.popFromList(student.drafted_mentor_id_group_id_list, mentor.id, mentor.group_id);

    mentorIds = BulkMatch.UserIdGroupIdList.getUserIds(student.drafted_mentor_id_group_id_list);
    angular.forEach(mentorIds, function(mentorId) {
      newDraftedMentorsHtml += $scope.mentors_hash[mentorId].name_with_profile_url;
      newDraftedMentorsHtml += ", ";
    });
    if(!!newDraftedMentorsHtml) {
      // Strip trailing comma and space characters
      newDraftedMentorsHtml = newDraftedMentorsHtml.slice(0, -2);
    }
    student.drafted_mentors_html = newDraftedMentorsHtml;
  };

  $scope.updateMentorListMentorToMentee = function(mentor, student, listName){
    if(listName == $scope.mentorLists.connected) {
      mentorIdGroupIdList = student.connected_mentor_id_group_id_list;
    } else if(listName == $scope.mentorLists.drafted) {
      mentorIdGroupIdList = student.drafted_mentor_id_group_id_list;
    }
    if(student[listName].length > 0) {
      student[listName] += ", ";
    }
    student[listName] += mentor.name_with_profile_url;
    BulkMatch.UserIdGroupIdList.pushIntoList(mentorIdGroupIdList, mentor.id, mentor.group_id);
  };

  $scope.updateMentorList = function(student, listName) {
    if(listName == $scope.mentorLists.connected) {
      mentorIdGroupIdList = student.connected_mentor_id_group_id_list;
    } else if(listName == $scope.mentorLists.drafted) {
      mentorIdGroupIdList = student.drafted_mentor_id_group_id_list;
    }
    mentorIds = BulkMatch.UserIdGroupIdList.getUserIds(mentorIdGroupIdList);

    angular.forEach(student.selected_mentors, function(mentorId) {
      mentor = $scope.mentors_hash[mentorId];
      notInMentorIdGroupIdList = (BulkMatch.UserIdGroupIdList.lookupList(mentorIdGroupIdList, mentorId, student.group_id) == -1);

      if(notInMentorIdGroupIdList) {
        mentor.slots_available--;
        if(listName == $scope.mentorLists.connected) {
          mentor.connections_count++;
        }
        if(mentorIds.indexOf(mentorId) == -1) {
          if(student[listName].length > 0) {
            student[listName] += ", ";
          }
          student[listName] += mentor.name_with_profile_url;
        }
        BulkMatch.UserIdGroupIdList.pushIntoList(mentorIdGroupIdList, mentorId, student.group_id);
      }
    });
  };

  $scope.updateStudentList = function(mentor, listName) {
    if(listName == $scope.studentLists.connected) {
      studentIdGroupIdList = mentor.connected_student_id_group_id_list;
    } else if(listName == $scope.studentLists.drafted) {
      studentIdGroupIdList = mentor.drafted_student_id_group_id_list;
    }
    studentIds = BulkMatch.UserIdGroupIdList.getUserIds(studentIdGroupIdList);

    angular.forEach(mentor.selected_students, function(studentId) {
      student = $scope.students_hash[studentId];
      notInStudentIdGroupIdList = (BulkMatch.UserIdGroupIdList.lookupList(studentIdGroupIdList, studentId, mentor.group_id) == -1);

      if(notInStudentIdGroupIdList) {
        mentor.pickable_slots--;
        if(listName == $scope.studentLists.connected) {
          mentor.connections_count++;
        }
        if(studentIds.indexOf(studentId) == -1) {
          if(mentor[listName].length > 0) {
            mentor[listName] += ", ";
          }
          mentor[listName] += student.name_with_profile_url;
        }
        BulkMatch.UserIdGroupIdList.pushIntoList(studentIdGroupIdList, studentId, mentor.group_id);
      }
    });
  };

  $scope.removeFromDraftedMentorsList = function(student) {
    var newDraftedMentorsHtml = "";

    angular.forEach(student.selected_mentors, function(mentorId) {
      mentor = $scope.mentors_hash[mentorId];
      BulkMatch.UserIdGroupIdList.popFromList(student.drafted_mentor_id_group_id_list, mentorId, student.group_id);
      mentor.slots_available++;
    });

    mentorIds = BulkMatch.UserIdGroupIdList.getUserIds(student.drafted_mentor_id_group_id_list);
    angular.forEach(mentorIds, function(mentorId) {
      newDraftedMentorsHtml += $scope.mentors_hash[mentorId].name_with_profile_url;
      newDraftedMentorsHtml += ", ";
    });
    if(!!newDraftedMentorsHtml) {
      // Strip trailing comma and space characters
      newDraftedMentorsHtml = newDraftedMentorsHtml.slice(0, -2);
    }
    student.drafted_mentors_html = newDraftedMentorsHtml;
  };

  $scope.removeFromDraftedStudentsList = function(mentor) {
    var newDraftedStudentsHtml = "";

    angular.forEach(mentor.selected_students, function(studentId) {
      student = $scope.students_hash[studentId];
      BulkMatch.UserIdGroupIdList.popFromList(mentor.drafted_student_id_group_id_list, studentId, mentor.group_id);
      mentor.pickable_slots++;
    });

    studentIds = BulkMatch.UserIdGroupIdList.getUserIds(mentor.drafted_student_id_group_id_list);
    angular.forEach(studentIds, function(studentId) {
      newDraftedStudentsHtml += $scope.students_hash[studentId].name_with_profile_url;
      newDraftedStudentsHtml += ", ";
    });
    if(!!newDraftedStudentsHtml) {
      // Strip trailing comma and space characters
      newDraftedStudentsHtml = newDraftedStudentsHtml.slice(0, -2);
    }
    mentor.drafted_students_html = newDraftedStudentsHtml;
  };

  $scope.selectedStudentsWithGroupStatus = function(status){
    var selectedUserObjects = [];
    angular.forEach($scope.students, function(student){
      if(student.group_status==status && student.selected_for_bulk){
        selectedUserObjects.push(student);
      }
    });
    return selectedUserObjects;
  };

  $scope.selectedMentorsWithGroupStatus = function(status){
    var selectedUserObjects = [];
    angular.forEach($scope.mentors, function(mentor){
      if(mentor.group_status==status && mentor.selected_for_bulk){
        selectedUserObjects.push(mentor);
      }
    });
    return selectedUserObjects;
  };

  $scope.getStudentMentorMapFor = function(objectIdsToMap){
    var studentMentorObjects = {};
    angular.forEach(objectIdsToMap, function(object){
      if($scope.isMenteeToMentorMatch()){
        studentMentorObjects[object.id] = object.selected_mentors;
      }else{
        studentMentorObjects[object.id] = object.selected_students;
      }
    });
    return studentMentorObjects;
  };

  $scope.getGroupIds = function(userObjects){
    var groupIds = [];

    angular.forEach(userObjects, function(userObject){
      if(userObject.group_id) {
        groupIds.push(userObject.group_id);
      }
    });
    return groupIds;
  };

  $scope.hideUser = function(user){
    return (($scope.isDrafted(user) && !$scope.bulk_match_vars.show_drafted) ||
      ($scope.isPublished(user) && !$scope.bulk_match_vars.show_published));
  };

  $scope.showUser = function(user){
    return !($scope.hideUser(user));
  };

  $scope.isDrafted = function(user){
    var statusList = $scope.isMenteeToMentorMatch() ? user.drafted_mentor_id_group_id_list : user.drafted_student_id_group_id_list
    return BulkMatch.checkStatus(!$scope.recommendMentors, user, $scope.drafted_label, statusList);
  };

  $scope.isPublished = function(user){
    var statusList = $scope.isMenteeToMentorMatch() ? user.connected_mentor_id_group_id_list : user.connected_student_id_group_id_list
    return BulkMatch.checkStatus(!$scope.recommendMentors, user, $scope.published_label, statusList);
  };

  $scope.submitSettings = function(){
    var newMaxPickableSlot = parseInt(jQuery(BulkMatch.maxPickableSlots()).val());
    var oldMaxPickableSlot = parseInt(jQuery(BulkMatch.hiddenMaxPickableSlots()).val());
    if($scope.isMentorToMenteeMatch() || newMaxPickableSlot.toString().match(/^[0-9]+$/)){
      $scope.bulk_match_vars.show_drafted = !jQuery("#bulk_match_settings input#" + BulkMatch.type_underscore + "_show_drafted_false").is(":checked");
      $scope.bulk_match_vars.show_published = !jQuery("#bulk_match_settings input#" + BulkMatch.type_underscore + "_show_published_false").is(":checked");
      $scope.bulk_match_vars.request_notes = !jQuery("#bulk_match_settings input#" + BulkMatch.type_underscore + "_request_notes_false").is(":checked") && !$scope.recommendMentors;
      if(newMaxPickableSlot > oldMaxPickableSlot){
        var diffValue = newMaxPickableSlot - oldMaxPickableSlot;
        $scope.updatePickableSlots(diffValue);
      }
    }
    $scope.refreshView(1000);
  };

  $scope.updatePickableSlots = function(diffValue){
    var users = $scope.isMenteeToMentorMatch() ? $scope.mentors : $scope.students;
    angular.forEach(users, function(user){
      user.pickable_slots = user.pickable_slots+diffValue;
    });
  };

  $scope.getSortOptions = function(predicate_param, orientationType){
    var sortValue = -1;
    if(predicate_param == 'group_status'){
      $scope.updatePredicateReverse('group_status', '-group_status');
    }
    else if(predicate_param == 'name'){
      if(orientationType == BulkMatch.menteeOrientationType)
        $scope.updatePredicateReverse('name', '-name');
      else{
        $scope.updatePredicateFunction($scope.studentName);
        sortValue = predicate_param;
      }
    }
    else if(predicate_param == 'mentorName'){
      $scope.updatePredicateFunction($scope.mentorName);
      sortValue = predicate_param;
    }
    else if(predicate_param == 'best_mentor_score'){
      $scope.predicate = predicate_param;
      $scope.reverse = !$scope.reverse;
    }
    else if(predicate_param == 'pickable_slots'){
      $scope.updatePredicateReverse('pickable_slots', '-pickable_slots');
    }
    $scope.refreshDataAndUpdateSortOrder(sortValue, orientationType);
  };

  $scope.refreshDataAndUpdateSortOrder = function(sortValue, orientationType){
    $scope.updateStudentDetails();
    if(sortValue == -1) sortValue = $scope.predicate;
    var sortOrder = $scope.reverse;
    $http({
      method: 'GET',
      url: $scope.bulk_match_vars.update_settings_path,
      params: {sort_order: sortOrder, sort_value: sortValue, sort: true, orientation_type: orientationType}
    });
  };

  $scope.updateStudentDetails = function() {
    angular.forEach($scope.students, function(student) {
      student.best_mentor_score = student.current_best_mentor_score;
      //TODO : BULK_MATCH - This flag doesn't control match config summary anymore
      student.show_summary_details = false;
    });
  };

  $scope.setDefaultSort = function() {
    $scope.predicate = 'best_mentor_score';
    $scope.reverse = true;
  };

  $scope.predicate = (($scope.bulk_match_vars.sort_value == 'mentorName') ? $scope.mentorName : $scope.bulk_match_vars.sort_value);
  $scope.reverse = $scope.bulk_match_vars.sort_order;

  $scope.setSortOptions = function(orientationType, sortValue, sortOrder) {
    if(orientationType == BulkMatch.mentorOrientationType && sortValue == 'name')
      $scope.predicate = $scope.studentName;
    else if(sortValue == 'mentorName')
      $scope.predicate = $scope.mentorName
    else
      $scope.predicate = sortValue;
    $scope.reverse = sortOrder;
  };

  $scope.setSortOptions($scope.bulk_match_vars.orientation_type, $scope.bulk_match_vars.sort_value, $scope.bulk_match_vars.sort_order);

  $scope.updatePredicateFunction = function(functionName) {
    if($scope.predicate != functionName) {
      $scope.predicate = functionName;
      $scope.reverse = false;
    } else if($scope.reverse == false) {
      $scope.reverse = true;
    } else {
      $scope.setDefaultSort();
    }
  };

  $scope.updatePredicateReverse = function(posValue, negValue){
    if($scope.predicate == posValue){
      $scope.predicate = negValue;
      $scope.reverse = false;
    }
    else if($scope.predicate == negValue){
      $scope.setDefaultSort();
    }
    else{
      $scope.predicate = posValue;
      $scope.reverse = false;
    }
  };

  $scope.isOrderedByMentorName = function(predicateParam) {
    return (predicateParam == "mentorName" && $scope.predicate == $scope.mentorName);
  };

  $scope.isOrderedByStudentName = function(predicateParam) {
    return (predicateParam == "name" && $scope.predicate == $scope.studentName);
  };

  $scope.getSortClass = function(predicate_param){
    if(predicate_param == $scope.predicate || ('-'+predicate_param == $scope.predicate) || $scope.isOrderedByMentorName(predicate_param) || $scope.isOrderedByStudentName(predicate_param)){
      if(('-'+predicate_param == $scope.predicate) || $scope.reverse){
        return 'sort_desc';
      }
      return 'sort_asc';
    }
    return 'sort_both';
  };

  $scope.getTableHeaderClass = function(predicate_param, sortDisabled, additionalClass) {
    if(!!sortDisabled) return (additionalClass || "");
    else if(predicate_param == $scope.predicate || ('-'+predicate_param == $scope.predicate) || $scope.isOrderedByMentorName(predicate_param) || $scope.isOrderedByStudentName(predicate_param)){
      return 'gray-bg';
    }
    return '';
  };

  $scope.getStudentClass = function(student){
    if(student.highlight){
      return 'label label-success';
    }
    else if(student.group_status == $scope.published_label){
      return 'label label-primary';
    }
    else if(student.group_status == $scope.drafted_label){
      return 'label label-warning';
    }
    else if(student.group_status == $scope.unmatched_label || student.group_status == $scope.selected_label){
      return '';
    }
  };

  $scope.updateMenteeToMentorMasterClass = function(master){
    angular.forEach($scope.students, function(student){
      if(student.selected_mentor_id!=0 && student.group_status != $scope.published_label){
        student.highlight = master;
        student.selected_for_bulk = master;
      }
    });
  };

  $scope.updateMentorToMenteeMasterClass = function(master){
    angular.forEach($scope.mentors, function(mentor){
      if(mentor.group_status != $scope.published_label){
        mentor.highlight = master;
        mentor.selected_for_bulk = master;
      }
    });
  };

  $scope.showMatchConfigSummaryPopup = function(userObject, relationObjectId, src) {
    var params = $scope.setMatchConfigSummaryPopupParams(userObject, relationObjectId, src);
    var actionUrl = $scope.bulk_match_vars.summary_details_path;
    jQueryShowQtip(null, null, actionUrl, params, {largeModal: true});
  };

  $scope.setMatchConfigSummaryPopupParams = function(userObject, relationObjectId, src){
    var mentorId = $scope.isMenteeToMentorMatch() ? (relationObjectId || userObject.selected_mentors[0]) : userObject.id;
    var studentId = $scope.isMenteeToMentorMatch() ? userObject.id : (relationObjectId || userObject.selected_students[0]);
    var params = {student_id: studentId, mentor_id: mentorId, src: src, orientation_type: $scope.bulk_match_vars.orientation_type};
    return params;
  };

  $scope.fetchMenteeToMentorNotes = function(student, actionType){
    var studentId = student.id;
    var mentorId = student.selected_mentors[0];
    var dataParameters = { student_id: studentId, mentor_id: mentorId, action_type: actionType, group_id: student.group_id, orientation_type: $scope.bulk_match_vars.orientation_type };
    jQueryShowQtip('#student_records_'+studentId, 470, $scope.bulk_match_vars.fetch_notes_path, dataParameters, {method: "get", modal: true});
  };

  $scope.fetchMentorToMenteeNotes = function(mentor, actionType){
    var mentorId = mentor.id;
    var studentId = mentor.selected_students[0];
    var dataParameters = { mentor_id: mentorId, student_id: studentId, action_type: actionType, group_id: mentor.group_id, orientation_type: $scope.bulk_match_vars.orientation_type };
    jQueryShowQtip('#mentor_records_'+mentorId, 470, $scope.bulk_match_vars.fetch_notes_path, dataParameters, {method: "get", modal: true});
  };

  $scope.updatePair = function(event, userObjectId, studentId, updateType, options){
    var userObject = $scope.isMenteeToMentorMatch() ? $scope.getStudent(userObjectId) : $scope.getMentor(userObjectId) ;

    if(options.updateNotes){
      userObject.notes = jQuery('#cjs_notes_'+studentId).val();
    }
    else if(options.addMessage){
      var mentoringModelId = jQuery('#cjs_assign_mentoring_model').val();
      var groupName = jQuery('#group_name').val();
      userObject.message = jQuery('#cjs_message_'+studentId).val();
    }
    $scope.bulk_match_vars.request_notes = !jQuery('#cjs_request_notes').is(":checked");
    var form;
    if(event.target.hasAttribute("data-disable-with")){
      form = jQuery(event.target).closest("form")
      jQuery.rails.disableFormElements(form);
    }
    event.preventDefault();
    if(updateType == $scope.bulk_match_vars.update_type.draft){
      $scope.draftRequest(userObject, form);
    }
    else if(updateType == $scope.bulk_match_vars.update_type.publish){
      $scope.publishRequest(userObject, form, mentoringModelId, groupName);
    }
    $scope.refreshView(3000);
  };

  $scope.refreshView = function(refreshTime){
    $scope.$watch('updateview', function(){
      $timeout(function(){
        jQuery('#cjs_bulk_match_result').trigger("mouseover");
      }, refreshTime);
    });
  };

  $scope.updateSelectedRecord = function(userObject){
    userObject.highlight = !userObject.highlight;
    userObject.selected_for_bulk = userObject.highlight;
  };
};