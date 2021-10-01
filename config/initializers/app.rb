require "#{Rails.root}/lib/expose_sanitize"

module Brand
  module Defaults
    LABEL          = "Chronus Mentor"
    URL            = "https://chronus.com"
    DELIVERY_EMAIL = "no-reply@chronus.com"
    REPLY_TO_EMAIL = Proc.new{|obj_id_code,obj_type_code| "#{APP_CONFIG[:reply_to_email_username]}+#{obj_id_code}+#{obj_type_code}@m.chronus.com"}
    FAVICON        = "/favicons/chronus.ico?v=2" # Query string to force the browser to use the new favicon
  end
end

MAILER_ACCOUNT = {
  :user_name        => Brand::Defaults::LABEL,
  :email_address    => Brand::Defaults::DELIVERY_EMAIL,
  :reply_to_address => Proc.new{|obj_id_code, obj_type_code| Brand::Defaults::REPLY_TO_EMAIL.call(obj_id_code,obj_type_code)}
}

ANALYTICS_TRACKING_ENABLED = ['production', 'test', 'demo', 'productioneu', 'generalelectric', 'veteransadmin', 'nch', 'staging'].include?(Rails.env)

# Read the s3 credentials and load them

# These aws credentials are taken from opseng@chronus.com aws account. associate_tag is picked from amazon affiliates program(https://affiliate-program.amazon.com) connected to AWS account for API access. It requires root IAM credentials of an account and hence, we don't use our main AWS account(apolloops@chronus.com). opseng@chronus.com AWS account is part of lastpass. For access, contact OPS team.

Amazon::Ecs.options = {:AWS_access_key_id => ENV['AWS_PROD_API_KEY'], :AWS_secret_key => ENV['AWS_PROD_API_SECRET'], :associate_tag => 'chronusbooks-20'}

module SubProgram
  PROGRAM_PREFIX = "p/"
end

SESSION_DATA_CLEARANCE_PERIOD = 1.week