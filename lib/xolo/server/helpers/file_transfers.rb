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

        # TODO: This check should happen in Admin
        OK_PKG_EXTS = %w[.pkg .zip]

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

        # copy a .pkg file uploaded
        #############################
        def process_incoming_pkg
          filename = params[:file][:filename]
          tempfile = Pathname.new params[:file][:tempfile].path

          title = instantiate_title params[:title]
          version = instantiate_version params[:version]

          log.debug 'Processing incoming .pkg'
          pkg_id = params[:pkg_id].to_s.empty? ? nil : validate_pkg_id(params[:pkg_id])
          staged_file = stage_incoming_file

          # TODO: This check should happen in Admin
          unless OK_PKG_EXTS.include? staged_file.extname
            msg = "#{staged_file.basename}: Package files must end in .pkg or .zip (for old-style bundle packages)"
            log_error msg
            halt 400, { error: msg }
          end

          # The params that come with uploaded files are not JSON - they are
          # multipart urlencoded, which means that boolean false comes as
          # string 'false', and boolean true comes as string 'true'
          #
          # SO, we have to look for an explict 'true' to make sure we only
          # do dry runs when we want them
          dry_run = params[:dry_run].to_s.downcase == 'true'
          log.debug "DRY RUN IS: #{dry_run}"
          upload_pkg_in_thread(pkg_id, staged_file, dry_run: dry_run)

          # tell the sender that the upload worked
          status_msg = +"Uploaded '#{staged_file.basename}' to s3po. "
          status_msg << (dry_run ? 'DRY RUN, No upload to distribution servers..' : 'Upload to distribution servers. now underway.')

          { status: "#{status_msg}\n#{SLACK_UPLOAD_NOTIFICATION_MSG}" }
        end

      end # FileTransfers

    end # Helpers

  end # Server

end # module Xolo
