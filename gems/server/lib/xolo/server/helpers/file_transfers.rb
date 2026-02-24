# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

# frozen_string_literal: true

# main module
module Xolo

  module Server

    module Helpers

      module FileTransfers

        # Constants
        #######################
        #######################

        UPLOAD_ACTION = 'Upload'
        REUPLOAD_ACTION = 'Re-upload'

        # Module Methods
        #######################
        #######################

        # when this module is included
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # Instance Methods
        #######################
        ######################

        # upload a file for testing ... anything
        #################################
        def process_incoming_testfile
          progress 'starting test file upload', log: :debug

          params[:file][:filename]
          tempfile = Pathname.new params[:file][:tempfile].path

          progress "1/3 TempFile is #{tempfile} size is #{tempfile.size}... is it still uploading?", log: :debug
          sleep 2
          progress "2/3 TempFile is #{tempfile} size is #{tempfile.size}... is it still uploading?", log: :debug
          sleep 2
          progress "3/3 TempFile is #{tempfile} size is #{tempfile.size}... is it still uploading?", log: :debug
          progress 'all done', log: :debug
        end

        # Store an uploaded self service icon in the title's
        # directory. It'll be added to Policies and Patch Policies as needed
        # (increasing the bloat in the database, of course)
        #################################
        def process_incoming_ssvc_icon
          filename = params[:file][:filename]
          tempfile = Pathname.new params[:file][:tempfile].path

          log_info "Processing uploaded SelfService icon for #{params[:title]}"
          title = instantiate_title params[:title]
          title.save_ssvc_icon(tempfile, filename)
          title.configure_pol_for_self_service if title.self_service
        rescue => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }

          halt 400, { status: 400, error: msg }
        end

        # Upload an pkg installer from xadm to Jamf Pro,
        # and do all the processing around that
        ######################
        def process_and_upload_uploaded_pkg
          process_and_upload_to_jamf(
            params[:title],
            params[:version],
            pkg_src: params[:file][:tempfile].path,
            orig_filename: params[:file][:filename]
          )
        end

        # upload a package from autopkg to Jamf Pro
        # and do all the processing around that
        #
        # @param title [String] The title the package belongs to
        # @param version [String] The version string for the package
        # @return [void]
        ###########################################
        def process_and_upload_autopkg_pkg(title, version, pkg_src)
          process_and_upload_to_jamf(
            title,
            version,
            pkg_src: pkg_src
          )
        end

        # Process a pkg installer and upload to jamf
        #
        # @param title [String] the title name
        # @param version [String] the version string
        # @param pkg_src [String, Pathname] the path to the file to be uploaded to Jamf
        #   This could be one uploaded from xadm, or one created by autopkg
        #############################
        def process_and_upload_to_jamf(title, version, pkg_src:, orig_filename: nil)
          pkg_src = Pathname.new pkg_src
          orig_filename ||= pkg_src.basename.to_s

          log_info "Jamf: Processing installer package '#{pkg_src}' (#{pkg_src.size.pix_humanize_bytes}) for Jamf Dist upload, title '#{title}' version '#{version}'"

          # the Xolo::Server::Version that owns this pkg
          version = instantiate_version title: title, version: version
          version.lock

          # is this a re-upload? True if upload_date as any value in it
          action = upload_action(version)

          # make sure its a .pkg and return .pkg if OK
          file_extname = validate_uploaded_pkg pkg_src

          # Set the jamf_pkg_file, now that we know the extension
          jamf_pkg_file_name = "#{version.jamf_pkg_name}#{file_extname}"
          log_debug "Jamf: Uploaded package filename will be '#{jamf_pkg_file_name}'"
          version.jamf_pkg_file = jamf_pkg_file_name

          # The pkg_src will be staged here before uploading to the Dist Point
          staged_pkg = Xolo::Server::Title.title_dir(title) + jamf_pkg_file_name

          # remove any old one that might be there
          staged_pkg.delete if staged_pkg.file?

          # This will move/copy the pkg_src into the staged_pkg, signing it on the way if needed, and
          # delete the original pkg_src file.
          sign_and_stage(pkg_src, staged_pkg)

          # Wrap component pkgs in a Distribution pkg if configured to do so
          staged_pkg = wrap_component_pkg_in_distribution(staged_pkg) if Xolo::Server.config.create_distribution_pkgs

          # upload the pkg via the API or with the uploader tool defined in config
          # This will set the checksum and manifest in the JPackage object
          upload_to_dist_point(version.jamf_package, staged_pkg)

          if action == REUPLOAD_ACTION
            # These must be set before calling wait_to_enable_reinstall_policy
            version.reupload_date = Time.now
            version.reuploaded_by = session[:admin]

            # This will make the version start a thread
            # that will wait some period of time (to allow for pkg uploads
            # to complete) before enabling the reinstall policy
            #
            # TODO: check to see that the upload is actually complete before enabling the policy,
            # instead of just waiting a set amount of time
            version.wait_to_enable_reinstall_policy
          else
            version.upload_date = Time.now
            version.uploaded_by = session[:admin]
          end
          version.log_change msg: "#{action}ed pkg file '#{staged_pkg.basename}' to Jamf Pro dist point(s)"

          # make note if the pkg is a Distribution package
          version.dist_pkg = pkg_is_distribution?(staged_pkg)

          # save the manifest on the server, just in case
          # TODO: Support sha3_512 in manifests
          version.manifest_file.pix_atomic_write(version.jamf_package.manifest)

          # save the checksum just in case
          version.sha_512 = version.jamf_package.checksum

          # don't save the admins local path to the pkg, just the filename they uploaded
          version.pkg_to_upload = orig_filename

          # save/update the local data file, since we've done stuff to update it
          version.save_local_data

          # log the upload
          version.log_change msg: "#{action} pkg file '#{staged_pkg.basename}'"

          # remove the staged pkg and the pkg_src
          staged_pkg.delete
          pkg_src.delete if pkg_src.file?
        rescue => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }
          halt 400, { status: 400, error: msg }
        ensure
          version.unlock
        end

        # Are we uploading or re-uploading a pkg that needs to be signed?
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        # @return [String] "Uploading" or "Re-uploading"
        ######################
        def upload_action(version)
          version.upload_date.pix_empty? ? UPLOAD_ACTION : REUPLOAD_ACTION
        end

        # If this pkg needs signing, do so putting the signed pkg in the staged_pkg location,
        # and delete the original pkg_src file.
        # If it doesn't need signing, just move it to the staged_pkg location.
        #
        # @param pkg_src [Pathname] the path to the file to be uploaded to Jamf
        # @param staged_pkg [Pathname] the path where the pkg should be staged for upload to Jamf
        # @return [void]
        def sign_and_stage(pkg_src, staged_pkg)
          if need_to_sign?(pkg_src)
            # This will put the signed pkg into the staged_pkg location
            sign_pkg(pkg_src, staged_pkg)
            log_debug "Signing complete, signed pkg is '#{staged_pkg}', deleting original file '#{pkg_src}'"
            pkg_src.delete if pkg_src.file?
          else
            log_debug "The .pkg file doesn't need signing, moving pkg_src to '#{staged_pkg}'"
            pkg_src.rename staged_pkg
          end
        end

        # Check if a package is a Distribution package, if not,
        # it is a component package and can't be used for
        # MDM deployment.
        #
        # @param pkg_file [Pathname, String] The path to the .pkg
        #
        # @return [Boolean] true if the pkg is a Distribution package
        ###########################################
        def pkg_is_distribution?(pkg_file)
          pkg_file = Pathname.new(pkg_file)
          raise ArgumentError, "pkg_file does not exist or not a file: #{pkg_file}" unless pkg_file.file?

          `/usr/bin/xar -tf #{pkg_file.to_s.shellescape}`.split("\n").include? 'Distribution'
        end

        # Wrap a component pkg in a Distribution pkg, return the path to the Distribution pkg
        #
        # @param component_pkg [Pathname, String] The path to the component .pkg
        #
        # @return [Pathname] The path to the new Distribution pkg
        ###########################################
        def wrap_component_pkg_in_distribution(orig_pkg)
          orig_pkg = Pathname.new(orig_pkg)

          raise ArgumentError, "pkg_file does not exist or not a file: #{orig_pkg}" unless orig_pkg.file?

          if pkg_is_distribution?(orig_pkg)
            log_debug "Package '#{orig_pkg.basename}' is already a Distribution pkg, not wrapping"
            return orig_pkg
          end

          log_info "Wrapping component pkg '#{orig_pkg.basename}' in a Distribution pkg"
          out_dir = orig_pkg.parent
          out_file = out_dir + "#{orig_pkg.basename(Xolo::DOT_PKG)}_dist#{Xolo::DOT_PKG}"
          if system "/usr/bin/productbuild –package #{orig_pkg.to_s.shellescape} #{out_file.to_s.shellescape}"
            orig_pkg.delete
            return out_file
          end

          raise "Failed to wrap component pkg '#{orig_pkg.basename}' in a Distribution pkg"
        end

        # upload a staged pkg to the dist point(s)
        # This will also update the checksum and manifest.
        #
        # @param jpkg [Jamf::JPackage] The package object for which the pkg is being uploaded
        # @param pkg_file [Pathname] The path to .pkg file being uploaded
        #
        # @return [void]
        ###########################################
        def upload_to_dist_point(jpkg, pkg_file)
          Thread.new do
            # via API
            if Xolo::Server.config.upload_tool.to_s.downcase == 'api'
              log_debug "Jamf: Attempting upload of #{pkg_file.basename} to primary dist point via API"
              jpkg.upload pkg_file # this will update the checksum and manifest automatically, and save back to the server
              log_info "Jamf: Uploaded #{pkg_file.basename} to primary dist point via API, with new checksum and manifest"

            # via upload tool defined in config
            else
              log_debug "Jamf: Regenerating manifest for package '#{jpkg.packageName}' from #{pkg_file.basename}"
              jpkg.generate_manifest(pkg_file)

              log_debug "Jamf: Recalculating checksum for package '#{jpkg.packageName}' from #{pkg_file.basename}"
              jpkg.recalculate_checksum(pkg_file)

              log_info "Jamf: Saving package '#{jpkg.packageName}' with new checksum and manifest"
              jpkg.save
              upload_via_tool(jpkg, pkg_file)
            end
          end # thread
        end

        # upload the pkg with the uploader tool defined in config
        #
        # @param version [Xolo::Server::Version] The version object
        # @param staged_pkg [Pathname] The path to the staged pkg
        #
        # @return [void]
        ###########################################
        def upload_via_tool(jpkg, pkg_file)
          log_info "Jamf: Uploading #{pkg_file.basename} to dist point(s) via upload tool"

          tool = Shellwords.escape Xolo::Server.config.upload_tool.to_s
          jpkg_name = Shellwords.escape jpkg.packageName
          pkg = Shellwords.escape pkg_file.to_s
          cmd = "#{tool} #{jpkg_name} #{pkg}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          if exit_status.success?
            log_debug "Jamf: upload tool succeeded in uploading #{pkg_file.basename} to dist point(s)."
            return
          end

          msg = "Uploader tool failed to upload #{pkg_file.basename} to dist point(s): #{stdouterr}"
          log_error msg
          raise msg
        end

        # Confirm and return the extension of the originally uplaoded file,
        # as .pkg
        #
        # @param filename [String] The original name of the file uploaded to Xolo.
        #
        # @return [String]  '.pkg' is the only valid one for now
        ###############################
        def validate_uploaded_pkg(filename)
          log_debug "Validating pkg file ext for '#{filename}'"

          file_extname = Pathname.new(filename).extname
          return file_extname if Xolo::OK_PKG_EXTS.include? file_extname

          raise "Bad filename '#{filename}'. Package files must end in #{Xolo::OK_PKG_EXTS.join(', or ')}"
        end

        # TODO: Use ruby-jss when it implements could-distribution-point rsrc
        #
        # @param check_principal [Boolean] when true, cloud DP must also be the principal.
        # @return [Boolean] Is a cloud distribution point defined, possible as principal?
        ###############################
        def cloud_dp_available?(check_principal: false)
          response = jamf_cnx.jp_get '/v1/cloud-distribution-point'
          return false if response[:cdnType] == 'NONE'

          check_principal ? response[:master] : true
        rescue Jamf::Connection::JamfProAPIError => e
          return false if jamf_cnx.last_http_response.status == 404

          raise e
        end

        # TODO: Use ruby-jss when it implements could-distribution-point rsrc
        #
        # Does a given pkg name exist on the cloud dp with 'ready' status?
        #
        # @param pkg_name [String] the name of the pkg to look for
        #
        # @return [Boolean] Is the pkg ready-to-go on the Cloud DP?
        ###############################
        def cloud_dp_pkg_ready?(pkg_name)
          return false unless cloud_dp_available?

          filt = CGI.escape "fileName=='#{pkg_name}'"
          response = jamf_cnx.jp_get "/v1/cloud-distribution-point/files?filter=#{filt}"

          # No fileserver I know of will allow multiples of a single filename....
          # so assume there's only zero or one
          data = response[:results].first
          return false unless data

          # once the status is ready, we should be good to go
          data[:status] == 'READY'
        end

        # TODO: Use ruby-jss when it implements could-distribution-point rsrc
        #
        # @return [Hash {String => String}] The Jamf ID => FileName of all 'READY' PACKAGE files on
        #   the Cloud DP.
        ###############################
        def cloud_dp_pkgs
          page = 0
          page_size = 1000
          pkgs = {}
          loop do
            response = jamf_cnx.jp_get "/v1/cloud-distribution-point/files?page=#{page}&page-size=#{page_size}"
            results = response[:results]
            break if results.empty?

            results.each do |f|
              next unless f[:type] == 'PACKAGE' && f[:status] == 'READY'

              # fileObjectId is the Jamf ID of the Package object for this DP file
              pkgs[f[:fileObjectId]] = f[:fileName]
            end
            page += 1
          end
          pkgs
        end

      end # FileTransfers

    end # Helpers

  end # Server

end # module Xolo
