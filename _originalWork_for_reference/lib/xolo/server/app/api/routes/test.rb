module Xolo

  # These routes are only for testing the server in irb

  # our server
  module Server
 class App < Sinatra::Base

    namespace API_V1_ROUTE_BASE do
      # api namespace

      get '/test' do
        body 'foo'.to_json
      end

      # end namespace
    end

  end # class App 
 end # module Server

end # module Xolo
