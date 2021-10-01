module EnvSpecificConstants
  ENV_INDEX =                             ["production",                           "productioneu",                         "generalelectric",                      "demo",                                 "nch",                                  "veteransadmin",                        "scanner",                              "staging",                              "releasestaging1",                      "releasestaging2",                      "opstesting",                           "standby",                              "training",                             "performance"]

  CRON_MONITOR_CONSTANTS = {
    "CRON_TASKS_MONITOR" =>               ["7ce57bc9-7e10-4216-8788-b7edbde1cb7c", "b9b5a129-577d-4338-9200-b9fb56e08a87", "27f03179-1f58-49eb-8b26-7c9f19db8222", "09f69ce5-2c44-468f-9992-b8fa0643e973", "87f33b8c-8e50-46e2-b034-da1afa0b9569", "9547d4bc-a427-40a4-b32b-c4c72a872b3f", "c0e8521c-f5db-4855-b9a1-8bf4827816d0", "5c7b238b-2d13-443b-a712-dee0dfdd1e9c", "bde6164f-395d-422a-8360-03d6848f2f1f", "85b97546-0d0a-443f-921d-a22e7917cb07", "8feb810f-0a18-40a2-b1ff-ef3cf7dc6a2a", "7bcbac96-763f-417a-a038-c866b637acdd", "8f208372-f582-4b24-8eb3-26769b49a491", "7f468652-cda6-473f-b138-0370f94b486d"]
  }

  STORAGE_CONSTANTS = {
    hosted: {
      "BANNER_STORAGE_OPTIONS" => { path: "programs/banners-new/:translation_id/:style.:extension", use_timestamp: true, include_defaults: [:general] },
      "LOGO_STORAGE_OPTIONS" => { path: "programs/logos-new/:translation_id/:style.:extension", use_timestamp: true, include_defaults: [:general] }
    },
    local: {
      "BANNER_STORAGE_OPTIONS" => { url: "/system/:attachment/:translation_id/:style/:filename" },
      "LOGO_STORAGE_OPTIONS" => { url: "/system/:attachment/:translation_id/:style/:filename" }
    }
  }

  USER_CONSTANTS = {
    hosted: {
      "DEFAULT_PICTURE" => {
        :small => "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/user_small.jpg",
        :medium => "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/user_medium.jpg",
        :large => "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/user_large.jpg"
      },
      "PREVIEW_PROFILE_PICTURE": {
        RoleConstants::MENTOR_NAME => "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/mentoring_model_preview_mentor.jpg",
        RoleConstants::STUDENT_NAME =>  "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/mentoring_model_preview_mentee.jpg",
        RoleConstants::TEACHER_NAME =>  "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/mentoring_model_preview_teacher.jpg"
      }
    },
    local: {
      "DEFAULT_PICTURE" => {
        :small => "/assets/v3/user_small.jpg",
        :medium => "/assets/v3/user_medium.jpg",
        :large => "/assets/v3/user_large.jpg"
      },
      "PREVIEW_PROFILE_PICTURE": {
        RoleConstants::MENTOR_NAME => "/assets/mentor.jpg",
        RoleConstants::STUDENT_NAME => "/assets/mentee.jpg",
        RoleConstants::TEACHER_NAME => "/assets/teacher.jpg"
      }
    }
  }

  GROUP_CONSTANTS = {
    hosted: {
      "DEFAULT_LOGO" => "https://#{CHRONUS_MENTOR_ASSETS_BUCKET}.#{GLOBAL_ASSETS_DOMAIN_URL}/global-assets/images/group_profile.png"
    },
    local: {
      "DEFAULT_LOGO" => "/assets/icons/group_profile.png"
    }
  }

  MODULE_TO_CONSTANT_MAPPER = {
    "CronMonitorConstants" => CRON_MONITOR_CONSTANTS,
    "StorageConstants" => STORAGE_CONSTANTS,
    "UserConstants" => USER_CONSTANTS,
    "GroupConstants" =>  GROUP_CONSTANTS
  }

  class << self
    def generate(klass, suffix)
      data = constant_to_key_mapper(MODULE_TO_CONSTANT_MAPPER[klass.name], ENV_INDEX.index(suffix))
      data.each do |constant_name, value|
        klass.const_set(constant_name, value)
      end
    end

    def generate_with_host_type(klass, host_type, default_options = {})
      data = MODULE_TO_CONSTANT_MAPPER[klass.name][host_type]
      data.each do |constant_name, value|
        if value.instance_of?(String)
          final_value = value
        else
          final_value = {}
          default_options_to_include = value.delete(:include_defaults) || []
          default_options_to_include.each do |default_option_to_include|
            final_value.merge!(default_options[default_option_to_include] || {})
          end
          final_value.merge!(value)
        end
        klass.const_set(constant_name, final_value)
      end
    end

    private

    def constant_to_key_mapper(constant_key_hash, environment_value)
      constant_key_hash.each do |key, value|
        constant_key_hash[key] = value[environment_value]
      end
      return constant_key_hash
    end
  end
end

# Common modules
module CronMonitorConstants; end
module StorageConstants; end
module GroupConstants; end
module UserConstants; end
