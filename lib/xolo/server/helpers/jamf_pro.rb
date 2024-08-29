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

      # constants and methods for accessing the Jamf Pro server
      # from the Xolo server
      #
      # This is used both as a 'helper' in the Sinatra server,
      # and an included mixin for the Xolo::Server::Title and
      # Xolo::Server::Version classes.
      #
      # This means methods here are available in instances of
      # those classes, and in all routes, views, and helpers in
      # Sinatra.
      #
      module JamfPro

        # Constants
        #
        ##############################
        ##############################

        # The name of the Jamf::Package object that contains the xolo-client-data
        # NOTE: Set the category to Xolo::Server::JAMF_XOLO_CATEGORY
        CLIENT_DATA_PACKAGE_NAME = 'xolo-client-data'

        # The name of the package file that installs the xolo-client-data JSON file
        CLIENT_DATA_PACKAGE_FILE = 'xolo-client-data.pkg'

        # The package identifier for the xolo-client-data package
        CLIENT_DATA_PACKAGE_IDENTIFIER = 'com.pixar.xolo-client-data'

        # The name of the Jamf::Policy object that installs the xolo-client-data package
        # automatically on all managed Macs
        # NOTE: Set the category to Xolo::Server::JAMF_XOLO_CATEGORY
        CLIENT_DATA_AUTO_POLICY_NAME = 'xolo-client-data-auto'

        # The name of the Jamf::Policy object that installs the xolo-client-data package
        # manually on a managed Mac
        CLIENT_DATA_MANUAL_POLICY_NAME = 'xolo-client-data-manual'

        # The name of the client-data JSON file in the xolo-client-data package
        # this is the file that is installed onto managed Macs in
        # /Library/Application Support/xolo/
        CLIENT_DATA_FILE = 'client-data.json'

        # Module methods
        #
        # These are available as module methods but not as 'helper'
        # methods in sinatra routes & views.
        #
        ##############################
        ##############################

        # when this module is included
        ##############################
        def self.included(includer)
          Xolo.verbose_include includer, self
        end

        # when this module is extended
        def self.extended(extender)
          Xolo.verbose_extend extender, self
        end

        # Instance methods
        #
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

        # A connection to Jamf Pro via ruby-jss.
        #
        # We don't use the default connection but
        # use this method to create standalone ones as needed
        # and ensure they are disconnected, (or will timeout)
        # when we are done.
        #
        # TODO: allow using APIClients
        #
        # @return [Jamf::Connection] A connection object
        def jamf_cnx
          return @jamf_cnx if @jamf_cnx

          @jamf_cnx = Jamf::Connection.new(
            name: "jamf-pro-cnx-#{Time.now.strftime('%F-%T')}",
            host: Xolo::Server.config.jamf_hostname,
            port: Xolo::Server.config.jamf_port,
            verify_cert: Xolo::Server.config.jamf_verify_cert,
            ssl_version: Xolo::Server.config.jamf_ssl_version,
            open_timeout: Xolo::Server.config.jamf_open_timeout,
            timeout: Xolo::Server.config.jamf_timeout,
            user: Xolo::Server.config.jamf_api_user,
            pw: Xolo::Server.config.jamf_api_pw,
            keep_alive: false
          )
          log_debug "Jamf: Connected to Jamf Pro at #{@jamf_cnx.base_url} as user '#{Xolo::Server.config.jamf_api_user}'. KeepAlive: #{@jamf_cnx.keep_alive?}, Expires: #{@jamf_cnx.token.expires}. cnx ID: #{@jamf_cnx.object_id}"

          @jamf_cnx
        end

        # update the xolo-client-data package and the policy that installs it
        #
        # This package installs a JSON file with data about all titles and versions
        # for use by the xolo client on managed Macs.
        #
        # @return [void]
        #####################
        def update_client_data
          create_client_data_package_if_needed

          new_pkg = create_new_client_data_pkg_file
          upload_client_data_package new_pkg

          create_client_data_policies_if_needed
        end

        # Create the xolo-client-data package in Jamf Pro
        #
        # @return [void]
        #####################
        def create_client_data_package_
          return if Jamf::Package.all_names(cnx: jamf_cnx).include? CLIENT_DATA_PACKAGE_NAME

          # Create the package
          pkg = Jamf::Package.create(
            name: CLIENT_DATA_PACKAGE_NAME,
            category: Xolo::Server::JAMF_XOLO_CATEGORY,
            filename: CLIENT_DATA_PACKAGE_FILE,
            cnx: jamf_cnx
          )
          pkg.save
          # .pkg files are not uploaded here, but in the upload_client_data_package method

          log_debug "Jamf: Created package '#{CLIENT_DATA_PACKAGE_NAME}'"
        rescue StandardError => e
          raise "Jamf: Error creating Jamf::Package '#{CLIENT_DATA_PACKAGE_NAME}': #{e.class}: #{e}"
        end

        # Create the xolo-client-data policies in Jamf Pro
        #
        # @return [void]
        #####################
        def create_client_data_policies_if_needed
          all_pol_names = Jamf::Policy.all_names(cnx: jamf_cnx)

          unless all_pol_names.include? CLIENT_DATA_AUTO_POLICY_NAME
            create_client_data_policy CLIENT_DATA_AUTO_POLICY_NAME
          end

          return if all_pol_names.include? CLIENT_DATA_MANUAL_POLICY_NAME

          create_client_data_policy CLIENT_DATA_MANUAL_POLICY_NAME
        end

        # Create a xolo-client-data install policy in Jamf Pro
        #
        # @param
        #
        # @return [void]
        #####################
        def create_client_data_policy(pol_name)
          # Create the policy and set common attributes
          pol = Jamf::Policy.create name: pol_name, cnx: jamf_cnx
          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.add_package CLIENT_DATA_PACKAGE_NAME

          # scope to all computers
          pol.scope.set_all_targets

          # exclude the forced exclusion group if any
          if Xolo::Server.config.forced_exclusion
            pol.scope.set_exclusions :computer_groups, Xolo::Server.config.forced_exclusion
            log_info "Jamf: Excluded computer group: #{Xolo::Server.config.forced_exclusion} from policy '#{pol_name}'"
          end

          # Set the trigger event
          if pol_name == CLIENT_DATA_AUTO_POLICY_NAME
            pol.set_trigger_event :checkin, true
            pol.set_trigger_event :custom, Xolo::BLANK
          elsif pol_name == CLIENT_DATA_MANUAL_POLICY_NAME
            pol.set_trigger_event :checkin, false
            pol.set_trigger_event :custom, Xolo::CLIENT_DATA_MANUAL_POLICY_TRIGGER
          else
            err_msg = "Jamf: Invalid policy name '#{pol_name}' must be #{CLIENT_DATA_AUTO_POLICY_NAME} or #{CLIENT_DATA_MANUAL_POLICY_NAME}"
            log_err err_msg, alert: true
            return
          end

          pol.enable
          pol.save
          log_info "Jamf: Created policy '#{CLIENT_DATA_AUTO_POLICY_NAME}'"
        end

        # Create the xolo-client-data package installer file
        #
        # @return [Pathname] the path to the new package file
        #####################
        def create_new_client_data_pkg_file
          pkg_version = Time.now.strftime '%Y%m%d.%H%M%S.%6N'
          work_dir_prefix = "#{CLIENT_DATA_PACKAGE_NAME}-#{pkg_version}"

          pkg_work_dir = Pathname.new(Dir.mktmpdir(work_dir_prefix))

          root_dir = pkg_work_dir + 'pkgroot'
          xolo_client_dir = root_dir + 'Library' + 'Application Support' + 'xolo'
          xolo_client_dir.mkpath
          client_data_file = xolo_client_dir + CLIENT_DATA_FILE

          client_data_file.pix_save JSON.pretty_generate(client_data_hash)

          # Create the package
          pkg_file = pkg_work_dir + CLIENT_DATA_PACKAGE_FILE

          cmd = ['/usr/bin/pkgbuild']
          cmd << '--root'
          cmd << root_dir.to_s.shellescape
          cmd << '--identifier'
          cmd << CLIENT_DATA_PACKAGE_IDENTIFIER
          cmd << '--version'
          cmd << pkg_version
          cmd << pkg_file.to_s.shellescape
          cmd << '--sign'
          cmd << Xolo::Server.config.pkg_signing_identity.shellescape
          cmd << '--keychain'
          cmd << Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.shellescape

          log_info "Jamf: Creating package '#{CLIENT_DATA_PACKAGE_FILE}'"
          log_debug "Jamf: Running: #{cmd.join(' ')}"

          unlock_signing_keychain
          stdouterr, exit_status = Open3.capture2e(*cmd)
          raise "Error creating #{CLIENT_DATA_PACKAGE_FILE}: #{stdouterr}" unless exit_status.success?

          pkg_file
        end

        # @return [Hash] the data to put in the xolo-client-data JSON file
        #####################
        def client_data_hash
          {
            titles: Xolo::Server::Title.all_titles_hash
          }
        end

        # upload a new CLIENT_DATA_PACKAGE_FILE to the distribution point
        #
        # @param new_pkg [Pathname] the path to the package to upload
        #
        # @return [void]
        ####################
        def upload_client_data_package(new_pkg)
          # Upload the package
          log_debug "Jamf: Uploading package '#{CLIENT_DATA_PACKAGE_FILE}'"

          tool = Xolo::Server.config.upload_tool.to_s.shellescape
          jpkg_name = CLIENT_DATA_PACKAGE_NAME.shellescape
          pkg = new_pkg.to_s.shellescape
          cmd = "#{tool} #{jpkg_name} #{pkg}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          unless exit_status.success?
            raise "Uploader tool failed to upload #{new_pkg.basename} to dist point(s): #{stdouterr}"
          end

          log_info "Jamf: Uploaded new '#{CLIENT_DATA_PACKAGE_FILE}' via upload tool"
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
