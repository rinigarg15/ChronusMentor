jbuilder_responder(json, local_assigns) do
  json.programs do
    json.array! @programs do |program|
      json.id program.id
      json.name program.name
      json.description program.description
      json.root program.root
      
      setting = program.contact_admin_setting
      if setting.present?
        json.contact_admin do
          json.label setting.label_name
          json.url setting.contact_url
          json.instruction setting.content
        end
      end
    end
  end
end