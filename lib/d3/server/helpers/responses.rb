module D3

  module Server

    module Helpers

      # helpers for communicating with the Classic (eventually Jamf Pro) API
      module Responses

        # the standard JSON API response body
        #
        # @param status[Symbol] one of D3::Server::API_RESPONSE_STATUSES
        #
        # @param msg[String] the response message
        #
        # @param data[Hash] additional Hash keys/values to be included in the
        #   response
        #
        # @return [String] The JSON body of the response
        #
        def json_response(status, msg = '', **data)
          resp = { status: status, message: msg }
          resp.merge!(data).to_json
        rescue => e
          msg = e.message
          e.backtrace.each { |l| msg << "..#{l}" }
          { status: D3::API_ERROR_STATUS, message: msg }.to_json
        end

        # Format an error message in a standardized JSON object
        def error_response(message)
          json_response D3::API_ERROR_STATUS, message
        end

      end # module Response

    end # module API

  end # module server

end # module D3
