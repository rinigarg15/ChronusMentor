class LocationsController < ApplicationController
  skip_all_action_callbacks only: [:index]

  # TODO: Use model_auto_complete plugin as it is more sophisticated
  def index
    # To use the autocomplete, use the following code in the erb file of users controller
    # <%= location_autocomplete :member, :location_name, @is_location_empty?, {}, {} %>
    render json: Location.get_list_of_autocompleted_locations(params[:loc_name].strip)
  end

  def get_filtered_locations_for_autocomplete
    render json: Location.get_filtered_list_of_autocompleted_locations(params[:loc_name].strip, wob_member)
  end
end