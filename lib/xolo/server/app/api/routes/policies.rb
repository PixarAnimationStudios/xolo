module Xolo

  # the server
  module Server

    class App < Sinatra::Base

      POLICIES_ROUTE_BASE = '/policies'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace POLICIES_ROUTE_BASE do
          # policies namespace

          # use low-level JSS api calls to directly get the JSON
          # rather than parse from and then back to JSON
          get '/?' do
            # JSS::Policy.all(:refresh).to_json
            JSS.api.cnx[JSS::Policy::RSRC_BASE].get(accept: :json).body
          end

          # End of policy routes
        end
        # End of api routes
      end

    end # class App

  end # module Server

end # module Xolo
