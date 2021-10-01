class SetProgramPosition< ActiveRecord::Migration[4.2]
  def up
    Organization.all.each do |organization|
      organization.programs.order(:created_at).each_with_index do |program, index|
        program.update_column(:position, index)
      end
    end
  end
end
