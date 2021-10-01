# == Schema Information
#
# Table name: mentoring_model_task_comment_scraps
#
#  id                              :integer          not null, primary key
#  mentoring_model_task_comment_id :integer
#  scrap_id                        :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#

class MentoringModelTaskCommentScrap < ActiveRecord::Base
  belongs_to :scrap
  belongs_to :comment, :foreign_key => :mentoring_model_task_comment_id, class_name: MentoringModel::Task::Comment.name
end
