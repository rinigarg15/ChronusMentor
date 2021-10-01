module CoachingGoalActivitiesHelper
  def coaching_goal_activity_message_box(simple_form_object, options = {})
    rand_id = SecureRandom.hex(3)
    size_class = options[:size] || "form-control"
    simple_form_object.input :message, :as => :text, :input_html => {
      :rows => 5, :class => "cjs_goal_activity_message #{size_class}", :id => "coaching_goal_activity_message_#{rand_id}"}, 
      :placeholder => "feature.coaching_goal.content.message_placeholder".translate, :label_html => {:class => 'sr-only'}
  end
end