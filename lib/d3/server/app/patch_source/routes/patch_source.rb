#
module D3

  # These routes deal with being an 'external patch source'
  # for the JSS
  #  See https://www.jamf.com/jamf-nation/articles/497/jamf-pro-external-patch-source-endpoints
  #

  #
  module Server
 class App < Sinatra::Base

    # This endpoint returns a JSON array of Software Title Summary JSON objects.
    get '/software' do
    end

    # This endpoint returns a JSON array of Software Title Summary JSON objects
    # that match any of the given {ids}.
    # which are space or comma separated (?)
    get '/software/:ids' do
    end

    # This endpoint returns a Software Title JSON object.
    get '/patch/:id' do
    end

  end # class App 
 end # module Server

end # module D3
