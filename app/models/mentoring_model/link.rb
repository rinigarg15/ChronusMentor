# == Schema Information
#
# Table name: mentoring_model_links
#
#  id                 :integer          not null, primary key
#  child_template_id  :integer
#  parent_template_id :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class MentoringModel::Link < ActiveRecord::Base
  belongs_to :child_template, class_name: MentoringModel.name, inverse_of: :parent_links
  belongs_to :parent_template, class_name: MentoringModel.name, inverse_of: :child_links
end
