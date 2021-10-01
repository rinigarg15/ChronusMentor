class UpdateAdminViewAndMetricTitlesAndDescriptions< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      AbstractView.where(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES).includes(program: [{roles: [customized_term: :translations]}, :translations]).find_each do |abstract_view|
        # we want to update only if description or title has not been updated
        if abstract_view.description == "Users who have never been connected" || abstract_view.title == "Never Connected Users"
          mentee_term = abstract_view.program.roles.find{|s| s.name == RoleConstants::STUDENT_NAME}.customized_term.translation.pluralized_term
          abstract_view.description = "feature.abstract_view.admin_view.never_connected_mentees_description".translate(Mentees: mentee_term) if abstract_view.description == "Users who have never been connected"
          abstract_view.save!
          abstract_view.title = "feature.abstract_view.admin_view.never_connected_mentees_title".translate(Mentees: mentee_term) if abstract_view.title == "Never Connected Users"
          # updating of title might raise title uniqueness error. so using save! instead of save
          puts "Errors in abstract view with id #{abstract_view.id}: #{abstract_view.errors.full_messages.to_sentence}" unless abstract_view.save
        end
      end

      AbstractView.where(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES).includes(program: [{roles: [customized_term: :translations]}, :translations]).find_each do |abstract_view|
        if abstract_view.description == "Users who are currently not connected" || abstract_view.title == "Currently Unconnected Users"
          mentee_term = abstract_view.program.roles.find{|s| s.name == RoleConstants::STUDENT_NAME}.customized_term.translation.pluralized_term
          abstract_view.description = "feature.abstract_view.admin_view.currently_not_connected_mentees_description".translate(Mentees: mentee_term) if abstract_view.description == "Users who are currently not connected"
          abstract_view.save!
          abstract_view.title = "feature.abstract_view.admin_view.currently_not_connected_mentees_title".translate(Mentees: mentee_term) if abstract_view.title == "Currently Unconnected Users"
          # updating of title might raise title uniqueness error. so using save! instead of save
          puts "Errors in abstract view with id #{abstract_view.id}: #{abstract_view.errors.full_messages.to_sentence}" unless abstract_view.save
        end
      end

      Report::Metric.where(default_metric: Report::Metric::DefaultMetrics::NEVER_CONNECTED_MENTEES).includes(abstract_view: [{program: [{roles: [customized_term: :translations]}, :translations]}]).find_each do |metric|
        mentee_term = metric.abstract_view.program.roles.find{|s| s.name == RoleConstants::STUDENT_NAME}.customized_term.translation.pluralized_term
        metric.title = "feature.reports.default.default_metric_#{Report::Metric::DefaultMetrics::NEVER_CONNECTED_MENTEES}_title".translate(Mentees: mentee_term) if metric.title == "Never Connected Users"
        metric.description = "feature.reports.default.default_metric_#{Report::Metric::DefaultMetrics::NEVER_CONNECTED_MENTEES}_description".translate(Mentees: mentee_term) if metric.description == "Users who have never been connected"
        metric.save!
      end

      Report::Metric.where(default_metric: Report::Metric::DefaultMetrics::CURRENTLY_NOT_CONNECTED_MENTEES).includes(abstract_view: [{program: [{roles: [customized_term: :translations]}, :translations]}]).find_each do |metric|
        mentee_term = metric.abstract_view.program.roles.find{|s| s.name == RoleConstants::STUDENT_NAME}.customized_term.translation.pluralized_term
        metric.title = "feature.reports.default.default_metric_#{Report::Metric::DefaultMetrics::CURRENTLY_NOT_CONNECTED_MENTEES}_title".translate(Mentees: mentee_term) if metric.title == "Currently Unconnected Users"
        metric.description = "feature.reports.default.default_metric_#{Report::Metric::DefaultMetrics::CURRENTLY_NOT_CONNECTED_MENTEES}_description".translate(Mentees: mentee_term) if metric.description == "Users who are currently not connected"
        metric.save!
      end
      puts "updated abstract view titles.\n"
    end
  end

  def down
  end
end