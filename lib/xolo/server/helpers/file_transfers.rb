# Copyright 2024 Pixar
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

        # Store an uploaded self service icon in the title's
        # directory. It'll be added to Policies and Patch Policies as needed
        # (increasing the bloat in the database, of course)
        def process_incoming_ssvc_icon
          filename = params[:file][:filename]
          tempfile = Pathname.new params[:file][:tempfile].path

          log_info "Processing uploaded SelfService icon for #{params[:title]}"
          title = instantiate_title params[:title]
          title.save_ssvc_icon(tempfile)
        end

        # Handle an incoming pkg installer
        #############################
        def process_incoming_pkg
          log_info "Processing uploaded .pkg icon for version '#{params[:version]}' of title '#{params[:title]}'"

          filename = params[:file][:filename]
          tempfile = Pathname.new params[:file][:tempfile].path
          log_debug "Incoming pkg file '#{filename}', tempfile: '#{tempfile}' "

          # check its the kind of file we want
          file_extname = validate_uploaded_pkg(filename)

          # Set the pkg filename, now that we know the extension
          version = instantiate_version [params[:title], params[:version]]
          version.jamf_pkg_file = "#{version.jamf_pkg_name}#{file_extname}"

          log_debug "Jamf: Package.filename will be '#{version.jamf_pkg_file}'"

          # save/update the local data file with the pkg name
          version.save_local_data

          # move and rename the tempfile into the title dir,
          # signing it along the way if needed
          pkg_to_upload = Xolo::Server::Title.title_dir(version.title) + version.jamf_pkg_file
          # remove an old copy of this pkg
          pkg_to_upload.delete if pkg_to_upload.file?

          copy_and_sign_uploaded_pkg(filename, tempfile, pkg_to_upload)

          # create the pkg obj. in jamf
          create_jamf_package version

          # upload the pkg with the uploader tool defined in config
          upload_to_dist_point(version, pkg_to_upload)

          # delete the pkg from the title dir
          pkg_to_upload.delete
        end

        # upload the pkg with the uploader tool defined in config
        ###########################################
        def upload_to_dist_point(version, pkg_to_upload)
          log_info "Jamf: Uploading #{pkg_to_upload.basename} to dist point(s)"

          tool = Shellwords.escape Xolo::Server.config.upload_tool.to_s
          jpkg_name = Shellwords.escape version.jamf_pkg_name
          pkg = Shellwords.escape pkg_to_upload.to_s
          cmd = "#{tool} #{jpkg_name} #{pkg}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          return if exit_status.success?

          msg = "Uploader tool failed to upload #{pkg_to_upload.basename} to dist point(s): #{stdouterr}"
          log_error msg
          halt 400, { error: msg }
        end

        # make sure the pkg is sort of what we expect
        ###############################
        def validate_uploaded_pkg(filename)
          log_debug "Validating pkg file ext for '#{filename}'"

          file_extname = Pathname.new(filename).extname
          return file_extname if Xolo::OK_PKG_EXTS.include? file_extname

          msg = "Bad filename '#{filename}'. Package files must end in .pkg or .zip (for old-style bundle packages)"
          log_error msg
          halt 400, { error: msg }
        end

        # if the uploaded pkg needs to be signed, create the signed version in our title dirm
        # otherwise, just copy it into the title dir
        #######################################################
        def copy_and_sign_uploaded_pkg(filename, tempfile, pkg_to_upload)
          if system "/usr/sbin/pkgutil --check-signature #{Shellwords.escape tempfile.to_s}"
            log_debug "Jamf; Package file is already signed, copying tempfile to '#{pkg_to_upload.basename}'"
            tempfile.pix_cp pkg_to_upload
          else
            unlock_signing_keychain
            # The signing command takes an input file and creates an output file
            # so this accomplishes the 'rename' above.
            sign_uploaded_package(filename, tempfile, pkg_to_upload)
          end
        end

        # unlock the pkg signing keychain
        # TODO: Be DRY with the keychain stuff in Xolo::Admin::Credentials
        #############################
        def unlock_signing_keychain
          log_debug "Unlocking the signing keychain'"

          pw = Xolo::Server.config.pkg_signing_keychain_pw
          # first escape backslashes
          pw = pw.to_s.gsub '\\', '\\\\\\'
          # then single quotes
          pw.gsub! "'", "\\\\'"
          # then warp in sgl quotes
          pw = "'#{pw}'"

          outerrs = Xolo::BLANK
          exit_status = nil

          Open3.popen2e('/usr/bin/security -i') do |stdin, stdout_err, wait_thr|
            stdin.puts "unlock-keychain -p #{pw} '#{Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN}'"
            stdin.close
            outerrs = stdout_err.read
            exit_status = wait_thr.value # Process::Status object returned.
          end # Open3.popen2e
          return if exit_status.success?

          msg = "Error unlocking signing keychain: #{outerrs}"
          log_error msg
          halt 400, { error: msg }
        end

        # sign the unsigned tempfile, creating the signed file to upload
        ############################
        def sign_uploaded_package(orig_filename, tempfile, pkg_to_upload)
          sh_tmpf = Shellwords.escape tempfile.to_s
          sh_upf = Shellwords.escape pkg_to_upload.to_s
          sh_kch = Shellwords.escape Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
          sh_ident = Shellwords.escape Xolo::Server.config.pkg_signing_identity

          cmd = "/usr/bin/productsign --sign #{sh_ident} --keychain #{sh_kch} #{sh_tmpf} #{sh_upf}"
          log_debug "Signing #{pkg_to_upload.basename} using this command: #{cmd}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          return if exit_status.success?

          msg = "Failed to sign #{orig_filename}: #{stdouterr}"
          log_error msg
          halt 400, { error: msg }
        end

        # Create the Jamf::Package object for the uploaded installer if needed
        # @param version [Xolo::Server::Version]
        #############################
        def create_jamf_package(version)
          return if Jamf::Package.all_names.include? version.jamf_pkg_name

          log_info "Creating Jamf::Package '#{version.jamf_pkg_name}'"

          Jamf::Package.create(
            cnx: version.jamf_cnx,
            name: version.jamf_pkg_name,
            filename: version.jamf_pkg_file,
            reboot_required: reboot
          )
        rescue StandardError => e
          msg = "Failed to create Jamf::Package '#{version.jamf_pkg_name}': #{e.class}: #{e}"
          log_error msg
          halt 400, { error: msg }
        end

      end # FileTransfers

    end # Helpers

  end # Server

end # module Xolo
