# == Schema Information
#
# Table name: admin_views
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  program_id    :integer          not null
#  filter_params :text(16777215)
#  default_view  :integer
#  created_at    :datetime
#  updated_at    :datetime
#  description   :text(16777215)
#  type          :string(255)      default("AdminView")
#  favourite     :boolean          default(FALSE)
#  favourited_at :datetime
#  role_id       :integer
#

class FlagView < AbstractView
  module DefaultViews
    extend AbstractView::DefaultViewsCommons

    PENDING_FLAGS = {
      enabled_for: [Program, CareerDev::Portal],
      title: ->{ "feature.abstract_view.flag_view.pending_title".translate },
      description: ->{ "feature.abstract_view.flag_view.pending_description".translate },
      filter_params: ->{ AbstractView.convert_to_yaml({unresolved: true}) },
      default_view: -> { AbstractView::DefaultType::PENDING_FLAGS }
    }
    RESOLVED_FLAGS = {
      enabled_for: [Program, CareerDev::Portal],
      title: ->{ "feature.abstract_view.flag_view.resolved_title".translate },
      description: ->{ "feature.abstract_view.flag_view.resolved_description".translate },
      filter_params: ->{ AbstractView.convert_to_yaml({resolved: true}) }
    }

    class << self
      def all
        [PENDING_FLAGS]
      end
    end
  end

  def self.is_accessible?(program)
    program.flagging_enabled?
  end

  def count(alert=nil)
    filter = YAML.load(self.filter_params)
    Flag.get_flags(program, {filter: filter}).count
  end
end
