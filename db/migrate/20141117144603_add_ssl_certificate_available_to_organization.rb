class AddSslCertificateAvailableToOrganization< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :ssl_certificate_available, :boolean, default: false
  end
end
