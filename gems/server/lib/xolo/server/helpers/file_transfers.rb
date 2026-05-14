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

        # Thes values in the cdnType field of the Cloud DP definition
        # from the API indicate that there is no Cloud DP configured
        CLOUD_DP_NA = [nil, Xolo::BLANK, 'NONE'].freeze

        # How long to wait for a pkg to appear on the Cloud DP when uploading via API
        # before giving up and raising an error
        CLOUD_DP_UPLOAD_TIMEOUT = 1800 # seconds - 30 minutes

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
        # @param version [String, Xolo::Server::Version] the version string or object
        # @param pkg_src [String, Pathname] the path to the pkg
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
        # @param version [String, Xolo::Server::Version] the version string or object
        # @param pkg_src [String, Pathname] the path to the file to be uploaded to Jamf
        #   This could be one uploaded from xadm, or one created by autopkg
        # @param orig_filename [String, nil] the original filename of the pkg, e.g. as uploaded from
        #   an admin's computer. If not provided, the basename of pkg_src will be used.
        # @return [void]
        #############################
        def process_and_upload_to_jamf(title, version, pkg_src:, orig_filename: nil)
          pkg_src = Pathname.new pkg_src
          orig_filename ||= pkg_src.basename.to_s

          version = instantiate_version(title: title, version: version) if version.is_a?(String)

          staged_pkg = prep_pkg_for_upload(version, pkg_src)
          upload_pkg_in_thread(version, staged_pkg, orig_filename)
        rescue => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }
          halt 400, { status: 400, error: msg }
        ensure
          pkg_src.delete if pkg_src.file?
        end

        # Prep a .pkg before we start uploading to the dist point
        #
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        # @param pkg_src [Pathname] the path to the file to be uploaded to Jamf
        # @return [Pathname] the path to the staged pkg that is ready to be uploaded to Jamf
        #########################################
        def prep_pkg_for_upload(version, pkg_src)
          msg = "Jamf: Processing installer package '#{pkg_src}' (#{pkg_src.size.pix_humanize_bytes}) for Jamf Dist upload, title '#{version.title}' version '#{version.version}'"
          progress msg, log: :info

          version.jamf_pkg_file = dist_pkg_filename(version)
          log_debug "Jamf: Uploaded package filename will be '#{version.jamf_pkg_file}'"
          version.save_local_data

          # The pkg_src will be staged here before uploading to the Dist Point
          staged_pkg = Xolo::Server::Title.title_dir(version.title) + version.jamf_pkg_file

          # remove any old one that might be there
          staged_pkg.delete if staged_pkg.file?

          # This will move/copy the pkg_src into the staged_pkg, signing it on the way if needed, and
          # delete the original pkg_src file.
          sign_and_stage(pkg_src, staged_pkg, version)

          # Wrap component pkgs in a Distribution pkg if configured to do so
          staged_pkg = wrap_component_pkg_in_distribution(staged_pkg, version) if Xolo::Server.config.create_distribution_pkgs

          staged_pkg
        end

        # upload a prepped/staged pkg in a thread, and do the things that need to be done after upload,
        # like setting the upload/reupload date and user, enabling the reinstall policy if it's a reupload, etc
        #
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        # @param staged_pkg [Pathname] the path to the staged pkg that is ready to be uploaded to Jamf
        # @return [void]
        #####################################
        def upload_pkg_in_thread(version, staged_pkg, orig_filename)
          if @pkg_upload_thread&.alive?
            msg = "A pkg upload is already in progress for version '#{version}' - can't start another one until it's done"
            log_error msg
            raise msg
          end

          @pkg_upload_thread = Thread.new do
            begin
              # is this a re-upload? The jamf_pkg_file will have already
              # been updated to reflect the new filename with the _N_ if it's a re-upload
              re_uploading = version.jamf_pkg_file =~ /_(\d+)_\.pkg$/

              # disable reinstall policy if re-uploading,
              # will be re-enabled after the upload
              if re_uploading
                action = REUPLOAD_ACTION
                pol = version.jamf_auto_reinstall_policy
                pol.disable
                pol.save
              else
                action = UPLOAD_ACTION
              end

              upload_to_dist_point(version.jamf_package, staged_pkg)

              uploaded_by =
                if version.title_object.autopkg_enabled?
                  Xolo::Server::Helpers::AutoPkg::AUTOPKG_UPLOADED_BY
                elsif defined?(session)
                  session[:admin]
                end

              if re_uploading
                version.reupload_date = Time.now
                version.reuploaded_by = uploaded_by

                # if upload via API, wait for pkg to appear then enable the policy
                if upload_via_api?
                  wait_for_pkg_and_enable_reinstall_policy(version)

                # otherwise notify someone to confirm upload is complete before enabling the policy
                else
                  msg = "Please confirm that re-uploaded pkg '#{version.jamf_pkg_file}' is on the dist point and ready to go, then enable the reinstall policy '#{pol.name}' at #{jamf_auto_reinstall_policy_url}"
                  log_info msg, alert: true

                end # if upload_via_api?

                # update the dist filename in the jamf package object
                version.jamf_package.fileName = version.jamf_pkg_file
                version.jamf_package.packageName = version.jamf_pkg_name
                version.jamf_package.save

              # if this is a first-time upload, just set the upload date and user
              else
                version.upload_date = Time.now
                version.uploaded_by = uploaded_by
              end # if re_uploading
              version.save_local_data
              version.log_change msg: "#{action}ed pkg file '#{staged_pkg.basename}' to Jamf Pro dist point(s)"
            rescue => e
              msg = "Error in pkg upload thread: #{e.class}: #{e}"
              log_error msg
              e.backtrace.each { |line| log_error "..#{line}" }
            end # begin

            update_version_post_upload(version, staged_pkg, orig_filename)
          end # thread
        end

        # Wait for a re-uploaded pkg to appear on the Cloud DP after an API upload,
        # then enable the reinstall policy
        #
        # @param version [Xolo::Server::Version] the version that is being re-uploaded
        # @return [void]
        #####################
        def wait_for_pkg_and_enable_reinstall_policy(version)
          start_time = Time.now

          until cloud_dp_pkg_ready?(version.jamf_pkg_file)
            if Time.now - start_time > CLOUD_DP_UPLOAD_TIMEOUT
              msg = "Timed out waiting for pkg '#{version.jamf_pkg_file}' to appear on Cloud DP after upload via API"
              log_error msg
              raise msg
            end

            log_debug "Checking every minute for pkg '#{version.jamf_pkg_file}' to appear on Cloud DP after upload via API..."
            sleep 60
          end # until

          log_debug "Pkg '#{version.jamf_pkg_file}' is now on Cloud DP, enabling reinstall policy"
          pol = version.jamf_auto_reinstall_policy
          pol.enable
          pol.save

          msg = "Re-uploaded pkg '#{version.jamf_pkg_file}' is on the dist point and ready to go, reinstall policy '#{pol.name}' has been enabled"
          log_info msg, alert: true
        end

        # After uploading a pkg, update the version with info about the pkg,
        # like whether it's a dist pkg or not, and save the manifest and checksum
        # NOTE this is run as part of the upload thread.
        #
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        # @param staged_pkg [Pathname] the path to the staged pkg that was uploaded to Jamf
        # @return [void]
        ##############################
        def update_version_post_upload(version, staged_pkg, orig_filename)
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
          version.log_change msg: "Uploaded pkg file '#{staged_pkg.basename}' to dist point"
        ensure
          staged_pkg.delete if staged_pkg.file?
        end

        # What will be the name of the file on the dist point?
        # For a first upload, it will be 'xolo-<title>-<version>.pkg'
        #
        # If we are re-uploading, it will be 'xolo-<title>-<version>_N_.pkg'
        # where N is an integer (starting with 2) that increments with each re-upload,
        #
        # This is so that re-uploads don't have the same filename on the Dist Point, which could
        # be problematic. It also helps to visually see that this is a re-uploaded pkg
        # and not the original one.
        #
        # @param version [Xolo::Server::Version] the version that is being re-uploaded
        #
        # @return [String] the filename to use for the pkg on the dist point
        ####################
        def dist_pkg_filename(version)
          if version.upload_date.pix_empty?
            # no upload date, this is the first upload
            "#{version.jamf_pkg_name}#{Xolo::DOT_PKG}"

          elsif version.jamf_pkg_file.to_s =~ /_(\d+)_\.pkg$/
            # this is a re-upload, does the filename indicat a previous re-upload with a _N_ in the name?
            next_num = Regexp.last_match[1].to_i + 1
            "#{version.jamf_pkg_name}_#{next_num}_#{Xolo::DOT_PKG}"

          else
            # the first re-upload, just add _2_ before the extension
            "#{version.jamf_pkg_name}_2_#{Xolo::DOT_PKG}"
          end
        end

        # If this pkg needs signing, do so putting the signed pkg in the staged_pkg location,
        # and delete the original pkg_src file.
        # If it doesn't need signing, just move it to the staged_pkg location.
        #
        # @param pkg_src [Pathname] the path to the file to be uploaded to Jamf
        # @param staged_pkg [Pathname] the path where the pkg should be staged for upload to Jamf
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        # @return [void]
        def sign_and_stage(pkg_src, staged_pkg, version)
          if need_to_sign?(pkg_src, version)
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

        # Wrap a component pkg in a Distribution pkg, return the path to the Distribution pkg,
        # which should be the same as the orig_pkg
        #
        # @param orig_pkg [Pathname, String] The path to the component .pkg
        # @param version [Xolo::Server::Version] the version that is being uploaded/re-uploaded
        #
        # @return [Pathname] The path to the new Distribution pkg
        ###########################################
        def wrap_component_pkg_in_distribution(orig_pkg, version)
          orig_pkg = Pathname.new(orig_pkg)

          raise ArgumentError, "pkg_file does not exist or not a file: #{orig_pkg}" unless orig_pkg.file?

          if pkg_is_distribution?(orig_pkg)
            log_debug "Package '#{orig_pkg.basename}' is already a Distribution pkg, not wrapping"
            return orig_pkg
          end

          log_info "Wrapping component pkg '#{orig_pkg.basename}' in a Distribution pkg"
          out_dir = orig_pkg.parent
          out_file = out_dir + "#{orig_pkg.basename(Xolo::DOT_PKG)}_dist#{Xolo::DOT_PKG}"

          # the productbuild command, with signing if needed
          prodbuild_cmd = +"/usr/bin/productbuild --package #{orig_pkg.to_s.shellescape} "
          signing_reason =
            if version.pkg_is_from_autopkg && Xolo::Server.config.sign_autopkg_pkgs
              'autopkg'
            elsif !version.pkg_is_from_autopkg && Xolo::Server.config.sign_pkgs
              'uploaded'
            end

          if signing_reason
            log_info "Signing is enabled for #{signing_reason} pkgs, will sign the Distribution pkg as part of wrapping process"

            sh_kch = Shellwords.escape Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
            sh_ident = Shellwords.escape Xolo::Server.config.pkg_signing_identity
            unlock_signing_keychain
            prodbuild_cmd << "--sign #{sh_ident} --keychain #{sh_kch} "
          end

          prodbuild_cmd << out_file.to_s.shellescape

          log_debug "Wrapping component pkg in Distribution pkg with this command: #{prodbuild_cmd}"

          if system prodbuild_cmd
            # remove the component pkg
            orig_pkg.delete
            # rename the dist pkg to the original pkg name,
            out_file.rename orig_pkg

            return orig_pkg
          end

          raise "Failed to wrap component pkg '#{orig_pkg.basename}' in a Distribution pkg"
        end

        # are Dist Point uploads configured to be done via the API, or with an upload tool defined in config?
        #############################
        def upload_via_api?
          Xolo::Server.config.upload_tool.to_s.downcase == 'api'
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
          # via API
          if upload_via_api?
            log_debug 'Jamf: increasing the API timeout to 30 minutes for the pkg upload'
            jpkg.cnx.jp_cnx.options.timeout = 1800

            log_debug "Jamf: Attempting upload of #{pkg_file.basename} to primary dist point via API"
            # this will update the checksum and manifest automatically, and save back to the jamf pro server
            jpkg.upload pkg_file
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
        # @return [Hash] The Cloud DP definition from the API, if available, minus the keyPairId & privateKey
        #   If no cloud dp defined, returns { cdnType: 'NONE', master: false }
        ####################
        def cloud_dp_data
          return @cloud_dp_data if @cloud_dp_data

          @cloud_dp_data = jamf_cnx.jp_get '/v1/cloud-distribution-point'
          @cloud_dp_data.delete :privateKey
          @cloud_dp_data.delete :keyPairId
          @cloud_dp_data
        rescue Jamf::Connection::JamfProAPIError => e
          @cloud_dp_data = { cdnType: 'NONE', master: false }
          return @cloud_dp_data if jamf_cnx.last_http_response.status == 404

          raise e
        end

        # @return [Boolean] Is a cloud distribution point defined?
        ###############################
        def cloud_dp_available?
          !CLOUD_DP_NA.include? cloud_dp_data[:cdnType]
        end

        # TODO: Use ruby-jss when it implements could-distribution-point rsrc
        # @return [Boolean] Is a cloud distribution point defined?
        ###############################
        def cloud_dp_principal?
          cloud_dp_available? && cloud_dp_data[:master]
        end

        # TODO: Use ruby-jss when it implements could-distribution-point rsrc
        #
        # Does a given pkg name exist on the cloud dp with 'ready' status?
        #
        # @param pkg_name [String] the name of the pkg to look for
        #
        # @return [Boolean] Is the pkg ready-to-go on the Cloud DP?
        ###############################
        def cloud_dp_pkg_ready?(pkg_filename)
          return false unless cloud_dp_available?

          filt = CGI.escape "fileName=='#{pkg_filename}'"
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
