module D3

  # These routes are only for working with
  # the server data for the versions contained in titles
  #
  module Server

    class App < Sinatra::Base

      VERSIONS_ROUTE_BASE = '/versions'.freeze

      namespace API_V1_ROUTE_BASE do
        namespace VERSIONS_ROUTE_BASE do
          # version namespace

          # the summary list
          get '/?' do
            if params[:fields]
              D3::Server::Version.custom_summary_list params[:fields]
            else
              D3::Server::Version.json_summary_list
            end
          end

          # End of version namespace
        end

        namespace TITLES_ROUTE_BASE do
          # dealing with individual versions must always happen
          # thru the title that contains them, so the routes are here.
          # The only route in ../versions is the entire summary list

          # NOTE: we don't offer '/:title/versions' as a way to get a
          # summary list of versions for a title. Why? Because
          # that kind of processing is to be done on the clients - they
          # can retrieve the full summary list of versions from the
          # 'versions' route, and process it as needed (which they do in
          # the client D3::Server::Title and D3::Server::Version classes)

          # create a new version in a title
          post '/:title/version/:version', api_admin_only: true do
            halt_if_version_already_exists_in_title! params[:title], params[:version]
            request.body.rewind
            vers = D3::Server::Version.new_from_client_json request.body.read
            vers.create session[:user]
            title = D3::Server::Title.fetch vers.title
            title.latest_version = vers.version
            title.update session[:user]
            D3.logger.info "Created new version '#{params[:version]}' for title '#{params[:title]}' by #{whodat}"
            json_response(
              D3::API_OK_STATUS,
              D3::API_CREATED_MSG,
              id: vers.id,
              added_date: vers.added_date.iso8601
            )
          end

          # get a version in a title
          get '/:title/version/:version' do
            halt_if_version_not_found_in_title! params[:title], params[:version]
            D3::Server::Version.fetch(params[:title], params[:version]).to_json
          end

          # update a version in a title
          put '/:title/version/:version', api_admin_only: true do
            halt_if_version_not_found_in_title! params[:title], params[:version]
            request.body.rewind
            vers = D3::Server::Version.new_from_client_json request.body.read
            vers.update session[:user]
            D3.logger.info "Updated version '#{params[:version]}' for title '#{params[:title]}' by #{whodat}"
            json_response(
              D3::API_OK_STATUS,
              D3::API_UPDATED_MSG,
              id: vers.id,
              last_modified: vers.last_modified.iso8601
            )
          end

          # update a version in a title
          put '/:title/version/:version/release', api_admin_only: true do
            halt_if_version_not_found_in_title! params[:title], params[:version]
            vers = D3::Server::Version.new_from_client_json request.body.read
            msg =
              if vers.status == STATUS_RELEASED
                "#{params[:title]} v #{params[:version]} is already released by #{vers.added_by} at #{vers.added_date}"
              else
                vers.release session[:user]
                D3.logger.info "Released version '#{params[:version]}' of title '#{params[:title]}' by #{whodat}"
                "#{params[:title]} v #{params[:version]} has been released"
              end

            json_response(
              D3::Server::API_ERROR_STATUS,
              msg,
              id: vers.id,
              last_modified: vers.last_modified.iso8601
            )
          end

          # delete a version in a title
          delete '/:title/version/:version', api_admin_only: true do
            halt_if_version_not_found_in_title! params[:title], params[:version]
            D3::Server::Version.fetch(params[:title], params[:version]).delete
            D3.logger.info "Deleted version '#{params[:version]}' for title '#{params[:title]}' by #{whodat}"
            json_response(
              D3::API_OK_STATUS,
              D3::API_DELETED_MSG
            )
          end

          # end of titles namespace
        end

        # end of api namespace
      end

    end # class App

  end # module Server

end # module D3
