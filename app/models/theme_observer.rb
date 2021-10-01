class ThemeObserver < ActiveRecord::Observer

  def before_destroy(theme)
    programs_using_current_theme = theme.programs.all
    programs_using_current_theme.each do |program|
      program.assign_default_theme
    end
  end
end