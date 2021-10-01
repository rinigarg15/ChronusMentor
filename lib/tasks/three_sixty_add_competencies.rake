namespace :migration do
  task :three_sixty_add_questions => :environment do
    question_data = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/three_sixty/default_questions.yml")).result)
    organization = Organization.all
    ActiveRecord::Base.transaction do
      organization.each do |org|
        if org.three_sixty_competencies.empty?  
          question_data.each do |data|
            competency = org.three_sixty_competencies.create!(data.pick("title","description"))
            if data["questions"].present?
              data["questions"].each do |question|
                competency.questions.create!(question)
              end
            end
          end
        end
      end
    end
  end
end