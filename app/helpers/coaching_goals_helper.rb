module CoachingGoalsHelper
  DESCRIPTION_LENGTH = 200
  SIDE_PANE_LIMIT = 3

  def render_coaching_goal_status_icon(coaching_goal)
    content_tag(:h3, :class => "pull-left has-next cjs_coaching_goal_status_icon") do
      get_status_icon(coaching_goal)
    end
  end

  def coaching_goal_progress_bar(group, coaching_goal, options = {})
    completed_percentage = coaching_goal.completed_percentage
    is_from_show = options[:is_show_page].present?
    # Here +1 is added to the completed_percentage to display something on the progress bar
    # Also, appending a constant based on the show param, to decipher between the side pane and the show progress bar
    content = progress_bar(completed_percentage + 1, :id => "progress_#{coaching_goal.id}_#{is_from_show ? "show" : "other"}", 
      :class => "#{options[:width] || "width6"} #{options[:no_update] ? "" : "pull-left"} no-margin-bottom has-next",
      :tooltip => true, 
      :tooltip_content => "#{display_percentage(completed_percentage)}")
    content << append_update_link(group, coaching_goal, options[:is_show_page].present?) unless options[:no_update]
    content
  end

  def last_update_on(coaching_goal)
    last_coaching_goal_activity = coaching_goal.last_coaching_goal_activity
    content = ""
    if last_coaching_goal_activity
      content = "feature.coaching_goal.content.last_activity_on".translate(time: DateTime.localize(coaching_goal.last_coaching_goal_activity.updated_at, format: :full_display_no_time))
    else
      content = "feature.coaching_goal.content.no_activity_yet".translate
    end
    content.html_safe
  end

  def truncate_coaching_goal_description(text, length, url_path)
    truncated_text, is_truncated = truncate_html(text, :max_length => length, :status => true)
    content = truncated_text
    if is_truncated
      content << link_to("display_string.read_more_raquo_html".translate, url_path)
    end
    content
  end

  def append_update_link(group, coaching_goal, is_show_page)
    link_to("display_string.Update".translate, new_group_coaching_goal_coaching_goal_activity_path(group, coaching_goal, :is_show_page => is_show_page), 
      :class => "small cjs_coaching_goal_update_link strong")
  end

  def display_percentage(computed_score)
    "#{computed_score.to_i}%"
  end

  def get_coaching_goal_scoping_id(coaching_goal)
    "coaching_goal_#{coaching_goal.id}"
  end

  def bind_event_to_update_link
    javascript_tag do
      %Q[
        jQuery(document).ready(function(){
          CoachingGoals.inspectUpdateLink();
        });
      ]
    end  
  end

  def render_coaching_goal_activity_feed(group, coaching_goal, new_offset_id, activities)
    render :partial => 'common/activity_feed', :locals => {:more_url => 
      more_activities_group_coaching_goal_path(group, coaching_goal, :offset_id => new_offset_id, :format => :js), 
      :activities => activities, :force_well => false}
  end

  def get_formatted_goal_description(description, is_show_page, path_url)
    text = is_show_page ? description : truncate_coaching_goal_description(description, CoachingGoalsHelper::DESCRIPTION_LENGTH, path_url)
    simple_format(auto_link(text))
  end
  
  def get_coaching_goal_status_icon_and_text
    status_and_icon_hash = {
        :in_progress => {
          :icon_url => "v4/progress.gif",
          :status => "feature.connection.header.In_Progress".translate
        },
        :overdue => {
          :icon_url => "v4/overdue.gif",
          :status => "feature.connection.header.Overdue".translate
        },
        :completed => {
          :icon_url => "v4/completed.gif",
          :status => "feature.connection.header.Completed".translate
        }  
      }
    status_and_icon_hash
  end

  private

  def get_status_icon(coaching_goal)
    status_icon_and_text = get_coaching_goal_status_icon_and_text
    url_title = (if coaching_goal.in_progress?
      [status_icon_and_text[:in_progress][:icon_url], status_icon_and_text[:in_progress][:status]] 
    elsif coaching_goal.overdue?
      [status_icon_and_text[:overdue][:icon_url], status_icon_and_text[:overdue][:status]] 
    else
      [status_icon_and_text[:completed][:icon_url], status_icon_and_text[:completed][:status]] 
    end)
    image_tag(url_title[0], :title => url_title[1])
  end

end
