module Ckeditor
  module Hooks

    class ChronusAuthorization

      include AuthenticatedSystem
      include Ckeditor::Helpers::Controllers

      # See the +authorize_with+ config method for where the initialization happens.
      def initialize(controller)
        @controller = controller
        @controller.extend ControllerExtension
      end

      # This method is called in every controller action and should raise an exception
      # when the authorization fails. The first argument is the name of the controller
      # action as a symbol (:create, :destroy, etc.). The second argument is the actual model
      # instance if it is available.
      def authorize(action, model_object = nil)
        raise Authorization::PermissionDenied unless authorized?(action, model_object)
      end

      # This method is called primarily from the view to determine whether the given user
      # has access to perform the action on a given model. It should return true when authorized.
      # This takes the same arguments as +authorize+. The difference is that this will
      # return a boolean whereas +authorize+ will raise an exception when not authorized.
      def authorized?(action, model_object = nil)
        action = action.to_sym
        current_member = @controller.current_user_for_chronus
        if action && current_member.present?
          if current_member.is_admin? #TODO-CR should it be can_manage_<perm>?
            [:index, :create, :destroy].include? action
          else
            [:create].include? action
          end
        end
      end

      private

      module ControllerExtension
        def current_user_for_chronus
          # use ckeditor_current_user instead of default current_user so it works with
          # whatever current user method is defined with Ckeditor
          ckeditor_current_user
        end
      end
    end
  end
end

Ckeditor::AUTHORIZATION_ADAPTERS[:chronus] = Ckeditor::Hooks::ChronusAuthorization
