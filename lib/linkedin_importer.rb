class LinkedinImporter

  IMPORT_FIELDS = [
    "id",
    "first-name",
    "last-name",
    "positions:(title,company,startDate,endDate,isCurrent)"
  ]
  IMPORT_URI = "https://api.linkedin.com/v1/people/~:(#{IMPORT_FIELDS.join(',')})?format=json"
  VERIFY_ACCESS_TOKEN_URI = "https://api.linkedin.com/v1/people/~"

  attr_accessor :access_token, :raw_data, :formatted_data

  def initialize(access_token)
    self.access_token = access_token
  end

  def import_data
    self.formatted_data = {}
    self.raw_data = get_data
    return false if self.raw_data.blank?

    self.formatted_data[:id] = self.raw_data["id"]
    format_experiences
  end

  def is_access_token_valid?
    return false if self.access_token.blank?

    response = send_request(VERIFY_ACCESS_TOKEN_URI)
    is_response_valid?(response)
  end

  private

  # :nocov:
  def send_request(uri)
    begin
      url = URI(uri)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Get.new(url)
      request["authorization"] = "Bearer #{self.access_token}"
      http.request(request)
    rescue => _e
      return false
    end
  end
  # :nocov:

  def get_data
    response = send_request(IMPORT_URI)
    is_response_valid?(response) ? JSON.parse(response.body) : false
  end

  def format_experiences
    self.formatted_data[:experiences] = []
    return if self.raw_data["positions"].blank? || self.raw_data["positions"]["values"].blank?

    self.raw_data["positions"]["values"].each do |position|
      self.formatted_data[:experiences] << {
        job_title: position["title"],
        company: position["company"]["name"],
        start_year: position["startDate"].try(:[], "year"),
        start_month: position["startDate"].try(:[], "month"),
        end_year: position["endDate"].try(:[], "year"),
        end_month: position["endDate"].try(:[], "month"),
        current_job: position["isCurrent"]
      }
    end
  end

  def is_response_valid?(response)
    response.present? && (response.code.to_i == HttpConstants::SUCCESS)
  end
end