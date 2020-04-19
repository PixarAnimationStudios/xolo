module Xolo

  module Server

    # The server
    class App < Sinatra::Base

      CATEGORIES_ROUTE_BASE = '/categories'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace CATEGORIES_ROUTE_BASE do
          # categories namespace

          # use low-level JSS api calls to directly get the JSON
          # rather than parse from and then back to JSON
          get '/?' do
            # JSS::Category.all(:refresh).to_json
            JSS.api.cnx[JSS::Category::RSRC_BASE].get(accept: :json).body
          end

          # namespace categories
        end
        # namespace API_V1_ROUTE_BASE
      end

    end # class App

  end # module Server

end # module Xolo
