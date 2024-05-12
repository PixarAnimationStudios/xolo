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
        rescue StandardError => e
          msg = "#{e.class}: #{e}"
          log_error msg
          halt 400, { error: msg }
        end

        # Handle an uploaded pkg installer
        # TODO: wrap this in a thread, it might be very slow for large pkgs.
        # TODO: Also, when threaded, how to report errors?
        #############################
        def process_incoming_pkg
          log_info "Processing uploaded installer package for version '#{params[:version]}' of title '#{params[:title]}'"

          # the Xolo::Server::Version that owns this pkg
          version = instantiate_version [params[:title], params[:version]]

          # the original uploaded filename
          orig_filename = params[:file][:filename]
          log_debug "Incoming pkg file '#{orig_filename}' "
          file_extname = validate_uploaded_pkg(orig_filename)

          # Set the jamf_pkg_file, now that we know the extension
          version.jamf_pkg_file = "#{version.jamf_pkg_name}#{file_extname}"
          log_debug "Jamf: Package.filename will be '#{version.jamf_pkg_file}'"

          # The tempfile created by Sinatra when the pkg was uploaded from xadm
          tempfile = Pathname.new params[:file][:tempfile].path

          # The uploaded tmpfile will be staged here before uploading again to
          # the Jamf Dist Point(s)
          staged_pkg = Xolo::Server::Title.title_dir(version.title) + version.jamf_pkg_file
          # remove any old one
          staged_pkg.delete if staged_pkg.file?

          if need_to_sign?(tempfile)
            sign_uploaded_pkg(tempfile, staged_pkg)
          else
            log_debug "Jamf; Package file is already signed, copying tempfile to '#{staged_pkg.basename}'"
            tempfile.pix_cp staged_pkg
          end

          # create the pkg obj, polcies, etc. in jamf
          version.create_in_jamf

          # upload the pkg with the uploader tool defined in config
          upload_to_dist_point(version, staged_pkg)

          # now that we have a pkg and all the jamf stuff,
          # enable the patch in the title editor
          # this will enable the title also if needed
          version.enable_ted_patch

          # save/update the local data file, since we've done stuff to update it
          version.save_local_data

          # remove the staged pkg. The tmp file will go away on its own.
          staged_pkg.delete
        rescue StandardError => e
          msg = "#{e.class}: #{e}"
          log_error msg
          halt 400, { error: msg }
        end

        # upload the pkg with the uploader tool defined in config
        ###########################################
        def upload_to_dist_point(version, staged_pkg)
          log_info "Jamf: Uploading #{staged_pkg.basename} to dist point(s)"

          tool = Shellwords.escape Xolo::Server.config.upload_tool.to_s
          jpkg_name = Shellwords.escape version.jamf_pkg_name
          pkg = Shellwords.escape staged_pkg.to_s
          cmd = "#{tool} #{jpkg_name} #{pkg}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          return if exit_status.success?

          raise "Uploader tool failed to upload #{pkg_to_upload.basename} to dist point(s): #{stdouterr}"
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
