class CsvImporter::ProcessedRow
  attr_accessor :data, :errors, :state, :is_suspended_member, :user_to_be_invited, :user_to_be_updated, :raw_data

  def initialize(data, raw_data)
    @data = data
    @raw_data = raw_data
    @errors = {}
  end

  def has_errors?
    errors.present?
  end

  def can_show_errors?
    has_errors? && !is_suspended_member
  end

  def active_profile?
    (state == User::Status::ACTIVE) && !user_to_be_invited && !user_to_be_updated && !has_errors? && !is_suspended_member
  end

  def pending_profile?
    (state == User::Status::PENDING) && !user_to_be_invited && !user_to_be_updated && !has_errors? && !is_suspended_member
  end

  def is_suspended_member?
    is_suspended_member
  end

  def is_user_to_be_invited?
    user_to_be_invited && !has_errors? && !is_suspended_member
  end

  def is_user_to_be_updated?
    user_to_be_updated && !has_errors? && !is_suspended_member
  end

  def is_user_to_be_added?
    !user_to_be_updated && !has_errors? && !is_suspended_member && !user_to_be_invited
  end

  def to_be_imported?
    is_user_to_be_added? || is_user_to_be_updated? || is_user_to_be_invited?
  end

  def set_program_level_information(state_data, invite_data)
    self.state = state_data
    self.user_to_be_invited = invite_data
  end

  def email
    self.data[UserCsvImport::CsvMapColumns::EMAIL.to_sym]
  end

  def has_custom_login_identifier?
    self.data.has_key? UserCsvImport::CsvMapColumns::UUID.to_sym
  end

  class << self
    def select_rows_where(rows, property)
      rows.select{|row| row.send(property)}
    end
  end
end