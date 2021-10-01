module CareerDev::PortalsHelper
	module Headers
	    PORTAL_DETAILS = 1
	    ORG_PORTAL_DETAILS = 2
	  end

	def get_new_portal_wizard_view_headers
    wizard_info = ActiveSupport::OrderedHash.new
    wizard_info[Headers::PORTAL_DETAILS] = { label: "feature.portal.content.tab_captions.portal_details".translate(Portal: _Program) }
    wizard_info[Headers::ORG_PORTAL_DETAILS] = { label: "feature.portal.content.tab_captions.org_portal_details".translate }  if @current_organization.standalone?
    wizard_info
  end
end