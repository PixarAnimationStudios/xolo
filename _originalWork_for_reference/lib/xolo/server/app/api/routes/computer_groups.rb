module Xolo

  module Server

    # the server
    class App < Sinatra::Base

      COMPUTER_GROUPS_ROUTE_BASE = '/computer_groups'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace COMPUTER_GROUPS_ROUTE_BASE do
          # computer groups namespace

          # use low-level JSS api calls to directly get the JSON
          # rather than parse from and then back to JSON
          get '/?' do
            # JSS::ComputerGroup.map_all_ids_to(:name, refresh: true).to_json
            JSS.api.cnx[JSS::ComputerGroup::RSRC_BASE].get(accept: :json).body
          end

          # End of package routes
        end
        # End of api routes
      end

    end # class App

  end # module Server

end # module Xolo
