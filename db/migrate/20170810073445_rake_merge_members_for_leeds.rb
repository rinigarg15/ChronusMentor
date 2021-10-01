class RakeMergeMembersForLeeds< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        # these members records consist of user records in same program,
        # hence handling them separately
        organization = Program::Domain.get_organization("colorado.edu", "leedsmentoring")
        program = organization.programs.find_by(root: "yam")
        {
          "sallie.sangiorgio@colorado.edu" => "sallie.sangiorgio@ogilvy.com",
          "ashley.ziegler@colorado.edu" => "aziegler28@gmail.com"
        }.each do |email_to_discard, email_to_retain|
          member_to_discard = organization.members.find_by(email: email_to_discard)
          member_to_retain = organization.members.find_by(email: email_to_retain)
          user_to_discard = member_to_discard.user_in_program(program)
          user_to_retain = member_to_retain.user_in_program(program)
          ActiveRecord::Base.transaction do
            user_to_discard.accepted_rejected_membership_requests.update_all(admin_id: user_to_retain.id)
            user_to_discard.destroy
          end
        end

        # data_content_type validation is failing, so updating them directly using SQL
        Ckeditor::AttachmentFile.where(id: [3258, 3259, 3260, 3261, 3262]).update_all(assetable_id: 1795508)

        emails_map_in_yaml = {
          "john.housner@colorado.edu" => "johnhousner@gmail.com",
          "garrett.howard@colorado.edu" => "garrett.howard08@gmail.com",
          "allie.johnson@colorado.edu" => "alliemichelej@gmail.com",
          "kaylee.krough@colorado.edu" => "krough_k@hotmail.com",
          "jack.krowl@colorado.edu" => "jkrowl@amcap.com",
          "aubrey.lerche@colorado.edu" => "aubrey.lerche@barokas.com",
          "Jenna.Lester@colorado.edu" => "Jenna.C.Lester@key.com",
          "Thomas.Lotz@colorado.edu" => "Thomas.M.Lotz@Gmail.com",
          "micah.mador@colorado.edu" => "micahmador@gmail.com",
          "kevin.g.murphy@colorado.edu" => "kmurphy@rgl.com",
          "amy.m.nguyen@colorado.edu" => "amymnguyen8@deloitte.com",
          "brooke.pinchuck@colorado.edu" => "brooklynpinchuck@gmail.com",
          "cwr@quiwaholdings.com" => "cwrandle@yahoo.com",
          "srhoades28@gmail.com" => "samuel.rhoades@colorado.edu",
          "roy.romero@colorado.edu" => "roy@cbayco.com",
          "sallie.sangiorgio@colorado.edu" => "sallie.sangiorgio@ogilvy.com",
          "lindsey.schwartz@colorado.edu" => "Lisc3698@colorado.edu",
          "dalton.skach@colorado.edu" => "dalton.skach@gmail.com",
          "david.m.thayer@colorado.edu" => "dave.thayer@colorado.edu",
          "jillian.trubee@colorado.edu" => "trubeejillian@gmail.com",
          "alexander.tzeng@colorado.edu" => "alex.tzeng@paycomonline.com",
          "alexandra@sigmend.com" => "alexandra@freeandforsale.com",
          "rachelmwhite16@gmail.com" => "rachel.white-1@colorado.edu",
          "zawi2790@colorado.edu" => "Zackery.Withrow@gmail.com",
          "christopher.wright-1@colorado.edu" => "cwright@gmail.com",
          "ashley.ziegler@colorado.edu" => "aziegler28@gmail.com"
        }.to_yaml
        DeploymentRakeRunner.add_rake_task("common:member_manager:merge DOMAIN='colorado.edu' SUBDOMAIN='leedsmentoring' EMAILS_MAP_IN_YAML='#{emails_map_in_yaml}'")
      end
    end
  end

  def down
  end
end