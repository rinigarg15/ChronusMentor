// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
//

//= require_directory ../templates/common
//= require_directory ../templates/admin_views

//= require jquery/jquery-2.2.4.min
//= require jQuery_no_conflict
//= require jquery/jquery-migrate-1.4.1.min
//= require fastclick

// Please don't change the order of JS files below
// Button and tooltip related methods in jQuery UI and bootstrap conflict
//= require bootstrap/button
//= require jquery-ui-1.10.4
//= require bootstrap/transition
//= require bootstrap/alert
//= require bootstrap/carousel
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/modal
//= require bootstrap/tooltip
//= require bootstrap/popover
//= require bootstrap/scrollspy
//= require bootstrap/tab
//= require bootstrap/affix

//= require slimscroll/jquery.slimscroll.min.js
//= require jquery_ujs
//= require jquery_ujs_override
//= require jQuery_extensions
//= require jquery.scrollto
//= require jquery.blank
//= require utils.jquery
//= require initialize.jquery
//= require application.jquery
//= require base_app_jquery
//= require v3/plugins/jstz.min
//= require chr_utils
//= require onload.jquery
//= require jquery.qtip-2.min
//= require jquery.autosize
//= require availability_calendar
//= require jquery.corner
//= require jquery.corner_extended
//= require jquery.ba-bbq.min
//= require jquery.scrollelement
//= require columnizer
//= require modernizr
//= require cropper
//= require cookie
//= require jquery_uix_multiselect
//= require tag-it
//= require jquery.show_char_limit-1.2.0
//= require jquery.oembed
//= require jquery.cookie
//= require auto_logout
//= require jquery.dotdotdot.js
//= require select2
//= require angular.min
//= require admin_views/admin_views
//= require admin_views/admin_view_new_view
//= require bulk_match/bulk_match
//= require bulk_match/bulk_match_angular
//= require groups/groups
//= require reports/management_report
//= require ng-grid
//= require json3.min
//= require profile_questions
//= require coaching/coaching_goals
//= require message/message_search
//= require message/messages
//= require flag/flags
//= require jquery-add2cart
//= require date
//= require mailer_templates
//= require match_config/play_matching
//= require match_config/set_matching.js
//= require jquery.quicksearch
//= require jquery.sticky
//= require meetings/meetings
//= require meeting_requests/meeting_requests
//= require mentor_requests/mentor_requests
//= require membership_requests/membership_requests
//= require mentor_offers/mentor_offers
//= require users/import_users
//= require members/members_profile_data
//= require jquery.remotipart
//= require files-uploader
//= require three_sixty/three_sixty
//= require three_sixty/three_sixty_report
//= require mentoring_model/mentoring_models
//= require mentoring_model/goals
//= require mentoring_model/tasks
//= require mentoring_model/goal_template
//= require mentoring_model/task_template
//= require mentoring_model/task_template_progressive_form
//= require mentoring_model/milestone_templates
//= require mentoring_model/facilitation_templates
//= require mentoring_model/facilitation_template_progressive_form
//= require mentoring_model/progressive_form_common_elements
//= require mentoring_model/milestones
//= require group_checkins/checkins_kendo
//= require section_508.js
//= require markerclusterer
//= require project_requests/project_requests
//= require highcharts-ng
//= require reports/groups_report
//= require reports/demographic_report
//= require reports/outcomes_report
//= require reports/detailed_user_outcomes_report
//= require reports/detailed_connection_outcomes_report
//= require reports/outcomes_report_common
//= require reports/outcomes
//= require insecure_content_helper
//= require program_invitations/program_invitations
//= require campaign_management/campaign_management
//= require tour/tour_feature
//= require themes.js.erb
//= require jquery.raty
//= require feedback/responses/response.js.erb
//= require demo_programs
//= require mentoring_model/goal_activity
//= require home/feature_report
//= require localization
//= require surveys
//= require v3/jquery.ui.touch-punch.min
//= require plugin_overrides.js

//= require trip
//= require v3/bootstrap-tour


jQuery(document).ready(function(){
  jQuery('input[name=utf8]').remove();
});

(function($) {
  var hide, show;
  show = $.fn.show;
  $.fn.show = function() {
    this.removeClass("hidden hide");
    return show.apply(this, arguments);
  };
})(jQuery);

$(function() {
  return new FastClick(document.body);
});

jQuery('body').on('hidden.bs.modal', '.modal', function () {
  jQuery(this).removeData('bs.modal');
});
