module Xolo

  # the server
  module Server

    class App < Sinatra::Base

      SCRIPTS_ROUTE_BASE = '/scripts'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace SCRIPTS_ROUTE_BASE do
          # scripts namespace

          # use low-level JSS api calls to directly get the JSON
          # rather than parse from and then back to JSON
          get '/?' do
            # JSS::Script.all(:refresh).to_json
            JSS.api.cnx[JSS::Script::RSRC_BASE].get(accept: :json).body
          end

          # End of scripts routes
        end
        # End of api routes
      end

    end # class App

  end # module Server

end # module Xolo
