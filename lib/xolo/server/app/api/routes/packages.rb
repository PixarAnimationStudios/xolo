module Xolo

  module Server

    # the server
    class App < Sinatra::Base

      PACKAGES_ROUTE_BASE = '/packages'.freeze

      # TODO: move this?
      PACKAGE_UPLOAD_TMP_DIR = Pathname.new "#{Xolo::Server.config.data_dir}/pkg_uploads"

      namespace API_V1_ROUTE_BASE do
        namespace PACKAGES_ROUTE_BASE do
          # packages namespace
          #
          # D3 doesn't need the entirety of a JSS::Package - only
          # a few attributes. As such, only a Hash of data
          # is used between the d3 server and the d3 client apps.

          # an array of all the filenames ccurrently in the dist point
          # packages folder
          get '/filenames' do
            all_pkg_filenames.to_json
          end

          # A list of pkgs in the JSS
          # use low-level JSS api calls to directly get the JSON
          # rather than parse from and then back to JSON
          get '/?' do
            JSS.api.cnx[JSS::Package::RSRC_BASE].get(accept: :json).body
          end

          # Retrieve d3-related data about a specific jamf package
          get '/:package_id' do
            pkg = fetch_package params[:package_id]
            data = {}
            Xolo::PACKAGE_ATTRIBUTES.each { |pa| data[pa] = pkg.send(pa) }
            data.to_json
          end

          # create a new pkg in the JSS
          post '/?', api_admin_only: true do
            pkg = JSS::Package.make name: Dir::Tmpname.make_tmpname('d3tmp-file-name', nil)
            apply_new_pkg_vals pkg

            D3.logger.info "Created Jamf Package '#{pkg.name}' by #{whodat}"

            json_response Xolo::API_OK_STATUS, 'Created Jamf Package', pkg_name: pkg.name, pkg_id: pkg.id
          end

          # Process uploaded .pkg to be stored on the dist point
          #
          # Upload with:
          #   D3.cnx.post 'packages/1234/upload', file: File.new('path/to/pkg.pkg', 'rb')
          #
          # (RestClient::Resource knows to do the right thing when a
          #  File object is passed in)
          #
          post '/:package_id/upload', api_admin_only: true do
            uploaded_pkgfile = validate_uploaded_pkg params
            pkg = fetch_package params[:package_id]

            save_pkg_to_dist pkg, uploaded_pkgfile

            D3.logger.info "Uploaded .pkg file '#{uploaded_pkgfile.basename}' to DistPoint for Jamf Package '#{pkg.name}' by #{whodat}"

            json_response(Xolo::API_OK_STATUS, 'Upload complete')
          end

          # update a pkg in the JSS
          # request body is a JSON hash with Xolo::PACKAGE_ATTRIBUTES as keys
          #
          put '/:package_id', api_admin_only: true do
            pkg = fetch_package params[:package_id]
            apply_new_pkg_vals pkg

            # TODO: record in version/title changelog?
            D3.logger.info "Updated Jamf Package '#{name}' by #{whodat}"

            json_response Xolo::API_OK_STATUS, 'Updated Jamf Package', pkg_name: pkg.name, pkg_id: pkg.id
          end

          # delete a pkg in the JSS
          #
          delete '/:package_id', api_admin_only: true do
            pkg = fetch_package params[:package_id]
            name = pkg.name
            pkg.delete delete_file: true, rw_pw: Xolo::Server::Helpers::Auth.dist_point_pw, unmount: false

            D3.logger.info "Deleted Jamf Package '#{name}' by #{whodat}"

            json_response Xolo::API_OK_STATUS, 'Deleted Jamf Package', pkg_name: pkg.name, pkg_id: pkg.id
          end

          # End of package routes
        end
        # End of api route
      end

    end # class App

  end # module Server

end # module Xolo
