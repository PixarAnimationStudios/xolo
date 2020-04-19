module D3

  module Server

    module Helpers

      # API error handling
      module Errors

        # Stop API routes that need a login if not logged in
        def halt_if_not_logged_in!
          return if logged_in?
          halt 401, error_response('Login required')
        end

        # Stop login API routes for auth failures
        def halt_if_login_auth_role_unknown!
          return if D3::Server::Helpers::Auth::AUTH_ROLES.include? params[:role]
          D3.logger.debug "Login failed: unknown role: #{params[:role]}, from: #{request.ip}"
          headers['WWW-Authenticate'] = "Basic realm=\"#{params[:role]}\""
          halt 401, error_response("Login failed: Unknown role: #{params[:role]}")
        end

        # Stop login API routes for auth failures
        def halt_login_failed!(role, msg)
          D3.logger.debug "Login failed: #{msg}, role: #{role}, from: #{request.ip}"
          headers['WWW-Authenticate'] = "Basic realm=\"#{role}\""
          halt 401, error_response("Login failed: #{msg}")
        end

        # Stop routes if a requested title name isn't there.
        def halt_if_title_not_found!(name)
          return if D3::Server::Title.title_exist? name
          halt 404, error_response("No title with name '#{name}'")
        end

        # Stop routes if a desired title name already exists
        def halt_if_title_already_exists!(name)
          return unless D3::Server::Title.title_exist? name
          halt 409, error_response("Title with name '#{name}' already exists")
        end

        # Stop routes if a requested version/title combo doesn't exist
        def halt_if_version_not_found_in_title!(title, version)
          return if D3::Server::Version.version_exist?(title, version)
          halt 404, error_response("No version #{version} in title #{title}")
        end

        # Stop routes if a desired version/title combo already exists
        def halt_if_version_already_exists_in_title!(title, version)
          return unless D3::Server::Version.version_exist?(title, version)
          halt 409, error_response("Title '#{title}' already has version '#{version}'")
        end

        # Stop routes if a requested ExtensionAttribute name isn't there.
        def halt_if_ea_not_found!(name)
          return if D3::ExtensionAttribute.data_store.key? name
          halt 404, error_response("No ExtensionAttribute with name '#{name}'")
        end

        # Stop routes if a desired ExtensionAttribute name already exists
        def halt_if_ea_already_exists!(name)
          ind3 = D3::ExtensionAttribute.data_store.key? name
          injss = JSS::ComputerExtensionAttribute.all_names.include? name
          return if !ind3 && !injss
          halt 409, error_response("An ExtensionAttribute with name '#{name}' already exists")
        end


      end # module errors

    end # module api

  end # module server

end # module D3
