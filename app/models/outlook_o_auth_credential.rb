class OutlookOAuthCredential < MicrosoftOAuthCredential

  belongs_to :ref_obj, polymorphic: true

  module Provider
    NAME = "feature.calendar_sync_v2.label.outlook".translate
    IMAGE_URL = "calendar_sync_v2/outlook.png"
  end
end
