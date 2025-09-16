# Copyright 2025 Pixar
#
#    Licensed under the Apache License, Version 2.0 (the "Apache License")
#    with the following modification; you may not use this file except in
#    compliance with the Apache License and the following modification to it:
#    Section 6. Trademarks. is deleted and replaced with:
#
#    6. Trademarks. This License does not grant permission to use the trade
#       names, trademarks, service marks, or product names of the Licensor
#       and its affiliates, except as required to comply with Section 4(c) of
#       the License and to reproduce the content of the NOTICE file.
#
#    You may obtain a copy of the Apache License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the Apache License with the above modification is
#    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#    KIND, either express or implied. See the Apache License for the specific
#    language governing permissions and limitations under the Apache License.
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
        rescue StandardError => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }

          halt 400, { status: 400, error: msg }
        end

        # Handle an uploaded pkg installer
        # TODO: wrap this in a thread, it might be very slow for large pkgs.
        # TODO: Also, when threaded, how to report errors?
        #############################
        def process_incoming_pkg
          log_info "Processing uploaded installer package for version '#{params[:version]}' of title '#{params[:title]}'"

          # the Xolo::Server::Version that owns this pkg
          version = instantiate_version title: params[:title], version: params[:version]
          version.lock

          # the original uploaded filename
          orig_filename = params[:file][:filename]
          log_debug "Incoming pkg file '#{orig_filename}' "
          file_extname = validate_uploaded_pkg(orig_filename)

          # Set the jamf_pkg_file, now that we know the extension
          uploaded_pkg_name = "#{version.jamf_pkg_name}#{file_extname}"
          log_debug "Jamf: Package filename will be '#{uploaded_pkg_name}'"
          version.jamf_pkg_file = uploaded_pkg_name

          # The tempfile created by Sinatra when the pkg was uploaded from xadm
          tempfile = Pathname.new params[:file][:tempfile].path

          # The uploaded tmpfile will be staged here before uploading again to
          # the Jamf Dist Point(s)
          staged_pkg = Xolo::Server::Title.title_dir(params[:title]) + uploaded_pkg_name

          # remove any old one that might be there
          staged_pkg.delete if staged_pkg.file?

          if need_to_sign?(tempfile)
            # This will put the signed pkg into the staged_pkg location
            sign_uploaded_pkg(tempfile, staged_pkg)
          else
            log_debug "Uploaded .pkg file doesn't need signing, copying tempfile to '#{staged_pkg.basename}'"
            # Put the signed pkg into the staged_pkg location
            tempfile.pix_cp staged_pkg
          end

          # upload the pkg with the uploader tool defined in config
          # This will set the checksum and manifest in the JPackage object
          upload_to_dist_point(version.jamf_package, staged_pkg)

          # make note if the pkg is a Distribution package
          version.dist_pkg = pkg_is_distribution?(staged_pkg)

          # save the manifest just in case
          version.manifest_file.pix_atomic_write(version.jamf_package.manifest)

          # save the checksum just in case
          version.sha_512 = version.jamf_package.checksum

          # save/update the local data file, since we've done stuff to update it
          version.save_local_data

          # log the upload
          version.log_change msg: "Uploaded pkg file '#{staged_pkg.basename}'"

          # remove the staged pkg and the tempfile
          staged_pkg.delete
          tempfile.delete if tempfile.file?
        rescue StandardError => e
          msg = "#{e.class}: #{e}"
          log_error msg
          e.backtrace.each { |line| log_error "..#{line}" }
          halt 400, { status: 400, error: msg }
        ensure
          version.unlock
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

          tmpdir = Pathname.new(Dir.mktmpdir)
          workdir = tmpdir + "#{pkg_file.basename}-expanded"

          system "/usr/sbin/pkgutil --expand #{pkg_file.to_s.shellescape} #{workdir.to_s.shellescape}"

          workdir.children.map(&:basename).map(&:to_s).include? 'Distribution'
        ensure
          tmpdir.rmtree
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
          if Xolo::Server.config.upload_tool.to_s.downcase == 'api'
            jpkg.upload pkg_file # this will update the checksum and manifest automatically, and save back to the server
            log_info "Jamf: Uploaded #{pkg_file.basename} to primary dist point via API, with new checksum and manifest"
          else
            log_debug "Jamf: Regeneratin manifest for package '#{jpkg.packageName}' from #{pkg_file.basename}"
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
          return if exit_status.success?

          msg =  "Uploader tool failed to upload #{pkg_file.basename} to dist point(s): #{stdouterr}"
          log_error msg
          raise msg
        end

        # Confirm and return the extension of the originally uplaoded file,
        # either .pkg or .zip
        #
        # @param filename [String] The original name of the file uploaded to Xolo.
        #
        # @return [String] either '.pkg' or '.zip'
        ###############################
        def validate_uploaded_pkg(filename)
          log_debug "Validating pkg file ext for '#{filename}'"

          file_extname = Pathname.new(filename).extname
          return file_extname if Xolo::OK_PKG_EXTS.include? file_extname

          raise "Bad filename '#{filename}'. Package files must end in .pkg or .zip (for old-style bundle packages)"
        end

      end # FileTransfers

    end # Helpers

  end # Server

end # module Xolo
