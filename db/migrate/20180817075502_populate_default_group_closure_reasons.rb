class PopulateDefaultGroupClosureReasons < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      default_closure_reason_size = GroupClosureReason::DefaultClosureReason.all.select {|key,attributes| attributes[:is_default]}.size
      programs = Program.includes(:group_closure_reasons).select { |program| program.group_closure_reasons.default.size < default_closure_reason_size }

      programs.each do |program|
        current_default_closure_reasons = program.group_closure_reasons.default.collect(&:reason)
        expected_default_closure_reasons = GroupClosureReason::DefaultClosureReason.all(Mentoring_Connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term, mentoring_connection: program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term_downcase)
        expected_default_closure_reasons.each do |key,attributes|
          if !(current_default_closure_reasons.include? attributes[:reason]) && attributes[:is_default]
            program.group_closure_reasons.create!(attributes)
          end
        end
      end

    end
  end

  def down
  end
end