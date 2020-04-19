module D3

  module Server

    module Helpers

      # helpers for communicating with the Classic (eventually Jamf Pro) API
      module Jamf

        # Module methods - they don't become helper instance methods
        # in routes & filters, but are available everywhere
        ###################################

        # Our d3 server connection to the Jamf API
        # Jamf Server setting comes from /etc/ruby-jss.conf
        #
        def self.connect_to_jamf
          @jamf_cnx = JSS.api.connect(
            user: D3::Server.config.jamf_acct,
            pw: D3::Server::Helpers::Auth.jamf_pw
          )

          D3.logger.info "Established Jamf Classic API connection: #{JSS.api.user}@#{JSS.api.host}"
        end

        # Access to our Jamf API connection from wherever
        def self.jamf_cnx
          @jamf_cnx
        end

        # Instance methods - they become helper instance methods
        # in routes & filtersjamf_admin_cnx
        ###################################

        # Packages and Dist Points
        ###############################

        # @return [Array<String>] All the filenames in the dist. point
        #   packages folder
        #
        def all_pkg_filenames
          rwpw = D3::Server::Helpers::Auth.dist_point_pw
          mdp = JSS::DistributionPoint.master_distribution_point
          pkgs_folder = mdp.mount(rwpw, :rw) + JSS::Package::DIST_POINT_PKGS_FOLDER
          pkgs_folder.children.map { |c| c.basename.to_s }
        end

        # @param id[String, Integer] the id of desired pkg
        #
        # @return [JSS::Package]
        #
        def fetch_package(id)
          if id.is_a? String
            halt 400, error_response("Package id '#{id}' is not an integer") unless id.jss_integer?
          end
          JSS::Package.fetch id: id.to_i
        rescue JSS::NoSuchItemError
          halt 404, error_response("No package with id #{id}")
        end

        # Apply a hash of D3::PACKAGE_ATTRIBUTES from a
        # request body to a JSS::Package
        #
        # @param pkg[JSS::Package] the pkg to apply vals to
        #
        # @return [void]
        #
        def apply_new_pkg_vals(pkg)
          request.body.rewind
          vals = JSON.d3parse request.body.read

          halt 400, 'name: is required for new packages' if \
            vals[:name].to_s.empty? && !pkg.in_jss?

          D3::PACKAGE_ATTRIBUTES.each do |attr|
            next unless vals[attr]
            next if pkg.send(attr) == vals[attr]
            pkg.send "#{attr}=", vals[attr]
          end

          pkg.save
        end

        # Validate an uploaded file to be added to the dist point for a
        # JSS::Package, and move it to disk from temp-space
        #
        # File name must end with .pkg, must not exist on the dist. point,
        # and if pkgutil is available, it'll try to list the contents,
        # which will fail if it isn't a real .pkg.
        #
        # If config.validate_pkg_signatures is on, the pkg must be signed
        # in a way that passes GateKeeper.
        #
        # @param file[File] the file to check
        #
        # @return [Pathname] the validated uploaded file
        #
        def validate_uploaded_pkg(params)
          halt 400, error_response('No pkg file provided') unless \
            params[:file] && \
            (tmpfile = params[:file][:tempfile]) && \
            (name = params[:file][:filename])

          halt 400, error_response("Uploaded file must end with #{D3::DOT_PKG}") \
            unless name.end_with? D3::DOT_PKG

          halt 400, error_response("File named '#{name}' already exists on distribution point") \
            if all_pkg_filenames.include? name

          # move the file out of sinatra's tmpfile space
          D3::Server::App::PACKAGE_UPLOAD_TMP_DIR.mkpath
          file_to_store = D3::Server::App::PACKAGE_UPLOAD_TMP_DIR + name
          file_to_store.open('wb') { |f| f.write tmpfile.read }

          if D3::PKGUTIL.executable?
            path = Shellwords.escape file_to_store.to_s
            halt 400, error_response('Uploaded file is not a valid .pkg') \
              unless system "#{D3::PKGUTIL} --payload-files #{path} &>/dev/null"

            if D3::Server.config.validate_pkg_signatures
              halt 400, error_response('Uploaded file failed signature validation') \
                unless system "#{D3::PKGUTIL} --check-signature #{path} &>/dev/null"
            end # if validate signature

          end # if pkgutil executable
          D3.logger.debug "Validated uploaded package '#{name}' from #{whodat}"

          file_to_store
        end

        # Add an uploaded .pkg to master dist point for a given pkg
        #
        # for details of the upload process
        #
        # TODO: should d3 support non-flat packages/mpackages?
        #
        # @param pkg[JSS::Package] the package associated with the file
        #
        # @param file[Pathname] the uploaded & validated .pkg file.
        #
        # @return [void]
        #
        def save_pkg_to_dist(pkg, file)
          rwpw = D3::Server::Helpers::Auth.dist_point_pw

          # delete any existing master file, false = don't unmount
          pkg.delete_master_file rwpw, false

          # update the pkgs filename
          fname = file.basename.to_s
          unless pkg.filename == fname
            pkg.filename = fname
            pkg.save
          end
          # save to dist point, false = don't unmount
          pkg.upload_master_file(file, rwpw, false)
        ensure
          file.delete if file.file?
        end

      end # module Jamf

    end # module api

  end # module server

end # module D3
