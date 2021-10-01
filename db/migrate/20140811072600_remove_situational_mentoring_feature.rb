class RemoveSituationalMentoringFeature< ActiveRecord::Migration[4.2]
  def up
    feature = Feature.find_by(name: "situational_mentoring")
    feature.destroy if feature.present?
  end

  def down
    Feature.create!(name: "situational_mentoring")
  end
end
