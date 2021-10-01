module EmailTheme
  DEFAULT_PRIMARY_COLOR = "#1eaa79"
  PRIMARY_COLOR = "$button-bg-color"

  extend ActiveSupport::Concern

  include UserMailerHelper

  included do
    helper_method :email_theme
  end

  def initilize_email_theme_colors
    @email_theme = {}
    set_level_object
    email_priamry_color = @level_object.email_priamry_color
    @email_theme[:primary_color] =  email_priamry_color.present? ? email_priamry_color : EmailTheme::DEFAULT_PRIMARY_COLOR
  end

  def email_theme
    @email_theme
  end
end