class Office365OAuthCredential < MicrosoftOAuthCredential

  belongs_to :ref_obj, polymorphic: true

  module Provider
    NAME = "feature.calendar_sync_v2.label.office365".translate
    IMAGE_URL = "calendar_sync_v2/office365.png"
  end
end
