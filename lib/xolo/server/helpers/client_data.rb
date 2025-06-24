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

      # Constants and methods for maintaining the client data package
      #
      # This is used as a 'helper' in the Sinatra server
      #
      # This means methods here are available in all routes, views, and helpers
      # the Sinatra server app.
      #
      # The client data package is a Jamf::JPackage that installs a JSON file on all
      # managed Macs. This JSON file contains data about all titles and versions, and
      # any other data that the xolo client needs to know about.
      #
      # It is updated automatically by the server when titles or versions are changed.
      #
      # It is used so that the xolo client can know what it needs to know about titles and
      # versions without having to query the server or do anything over a network other
      # than using the jamf binary.
      #
      # The downside is that the client data package is likely to be somewhat out of date,
      # but that is a tradeoff for the simplicity and security of the client.
      #
      # The client data package is installed in /Library/Application Support/xolo/client-data.json
      # it contains a JSON object with a 'titles' key, which is an object with keys for each title.
      # The data provided is that produced by the Title#to_h and Version#to_h methods.
      module ClientData

        # Constants
        #
        ##############################
        ##############################

        CLIENT_DATA_STR = 'client-data'

        # The name of the Jamf Package object that contains the xolo-client-data
        # NOTE: Set the category to Xolo::Server::JAMF_XOLO_CATEGORY
        CLIENT_DATA_PACKAGE_NAME = "#{Xolo::Server::JAMF_OBJECT_NAME_PFX}#{CLIENT_DATA_STR}"

        # The name of the package file that installs the xolo-client-data JSON file
        CLIENT_DATA_COMPONENT_PACKAGE_FILE = "#{CLIENT_DATA_PACKAGE_NAME}-component.pkg"

        CLIENT_DATA_PACKAGE_FILE = "#{CLIENT_DATA_PACKAGE_NAME}.pkg"

        # The package identifier for the xolo-client-data package
        CLIENT_DATA_PACKAGE_IDENTIFIER = "com.pixar.xolo.#{CLIENT_DATA_STR}"

        # The name of the Jamf::Policy object that installs the xolo-client-data package
        # automatically on all managed Macs
        # NOTE: Set the category to Xolo::Server::JAMF_XOLO_CATEGORY
        CLIENT_DATA_AUTO_POLICY_NAME = "#{CLIENT_DATA_PACKAGE_NAME}-auto"

        # The name of the Jamf::Policy object that installs the xolo-client-data package
        # manually on a managed Mac
        CLIENT_DATA_MANUAL_POLICY_NAME = "#{CLIENT_DATA_PACKAGE_NAME}-manual"

        # The name of the client-data JSON file in the xolo-client-data package
        # this is the file that is installed onto managed Macs in
        # /Library/Application Support/xolo/
        CLIENT_DATA_FILE = 'client-data.json'

        # The trgger event for the manual policy to update the client data JSON file
        CLIENT_DATA_MANUAL_POLICY_TRIGGER = 'update-xolo-client-data'

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

        # A mutex for the client data update process
        #
        # TODO: use Concrrent Ruby instead of Mutex
        #
        # @return [Mutex] the mutex
        #####################
        def self.client_data_mutex
          @client_data_mutex ||= Mutex.new
        end

        # Instance methods
        #
        # These are available directly in sinatra routes and views
        #
        ##############################
        ##############################

        # @return [Jamf::JPackage] the xolo-client-data package object
        #####################
        def client_data_jpackage
          return @client_data_jpackage if @client_data_jpackage

          @client_data_jpackage = Jamf::JPackage.fetch packageName: CLIENT_DATA_PACKAGE_NAME, cnx: jamf_cnx
        rescue Jamf::NoSuchItemError
          @client_data_jpackage = create_client_data_jamf_package
        end

        # update the xolo-client-data package and the policy that installs it
        #
        # This package installs a JSON file with data about all titles and versions
        # for use by the xolo client on managed Macs.
        #
        # This process is protected by a mutex to prevent multiple updates at the same time.
        #
        # @return [void]
        #####################
        def update_client_data
          # don't do anything if we are in developer/test mode
          if Xolo::Server.config.developer_mode?
            log_debug 'Jamf: Skipping client-data update in developer mode'
            return
          end

          log_info 'Jamf: Updating client-data package'

          # TODO: Use Concurrent Ruby instead of Mutex
          mutex = Xolo::Server::Helpers::ClientData.client_data_mutex

          until mutex.try_lock
            progress 'Waiting for another client data update to finish', log: :info
            sleep 5
          end

          new_pkg = create_new_client_data_pkg_file
          upload_to_dist_point client_data_jpackage, new_pkg

          create_client_data_policies_if_needed

          flush_client_data_policy_logs
        ensure
          mutex.unlock if mutex&.owned?
        end

        # Create and return the xolo-client-data package in Jamf Pro
        #
        # @return [Jamf::JPackage]
        #####################
        def create_client_data_jamf_package
          progress "Jamf: Creating package object '#{CLIENT_DATA_PACKAGE_NAME}'"

          info = "Installs the xolo client data JSON file into /Library/Application Support/xolo/#{CLIENT_DATA_FILE}"

          # Create the package
          pkg = Jamf::JPackage.create(
            cnx: jamf_cnx,
            packageName: CLIENT_DATA_PACKAGE_NAME,
            fileName: CLIENT_DATA_PACKAGE_FILE,
            categoryId: jamf_xolo_category_id,
            info: info
          )

          pkg.save
          # .pkg files are not uploaded here, but in the upload_client_data_package method

          log_debug "Jamf: Created package '#{CLIENT_DATA_PACKAGE_NAME}'"

          pkg
        rescue StandardError => e
          raise "Jamf: Error creating Jamf::JPackage '#{CLIENT_DATA_PACKAGE_NAME}': #{e.class}: #{e}"
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
          progress "Jamf: Creating policy '#{pol_name}'"

          # Create the policy and set common attributes
          pol = Jamf::Policy.create name: pol_name, cnx: jamf_cnx
          pol.category = Xolo::Server::JAMF_XOLO_CATEGORY
          pol.add_package CLIENT_DATA_PACKAGE_NAME

          # scope to all computers
          pol.scope.set_all_targets

          # exclude the forced exclusion group if any
          if valid_forced_exclusion_group_name
            pol.scope.set_exclusions :computer_groups, [valid_forced_exclusion_group_name]
            log_info "Jamf: Excluded computer group: #{Xolo::Server.config.forced_exclusion} from policy '#{pol_name}'"
          end

          # Set the trigger event and frequency
          if pol_name == CLIENT_DATA_AUTO_POLICY_NAME
            pol.set_trigger_event :checkin, true
            pol.set_trigger_event :custom, Xolo::BLANK
            pol.frequency = :daily
          elsif pol_name == CLIENT_DATA_MANUAL_POLICY_NAME
            pol.set_trigger_event :checkin, false
            pol.set_trigger_event :custom, CLIENT_DATA_MANUAL_POLICY_TRIGGER
            pol.frequency = :ongoing
          else
            err_msg = "Jamf: Invalid policy name '#{pol_name}' must be #{CLIENT_DATA_AUTO_POLICY_NAME} or #{CLIENT_DATA_MANUAL_POLICY_NAME}"
            log_err err_msg, alert: true
            return
          end
          pol.enable

          pol.save
          log_info "Jamf: Created policy '#{pol_name}'"
        end

        # Flush the logs for the xolo-client-data policies
        #
        # @return [void]
        #####################
        def flush_client_data_policy_logs
          progress "Jamf: Flushing logs for policy #{CLIENT_DATA_AUTO_POLICY_NAME}", log: :info
          pol = Jamf::Policy.fetch name: CLIENT_DATA_AUTO_POLICY_NAME, cnx: jamf_cnx
          pol.flush_logs
        end

        # Create the xolo-client-data package installer file.
        # The xolo client executable is deployed as a separate thing in a Xolo Title
        #
        # @return [Pathname] the path to the new package file
        #####################
        def create_new_client_data_pkg_file
          pkg_version = Time.now.strftime '%Y%m%d.%H%M%S.%6N'
          work_dir_prefix = "#{CLIENT_DATA_PACKAGE_NAME}-#{pkg_version}"

          pkg_work_dir = Pathname.new(Dir.mktmpdir(work_dir_prefix))

          # The client data JSON file
          root_dir = pkg_work_dir + 'pkgroot'
          xolo_client_dir = root_dir + 'Library' + 'Application Support' + 'xolo'
          xolo_client_dir.mkpath
          client_data_file = xolo_client_dir + CLIENT_DATA_FILE
          client_data_file.pix_save JSON.pretty_generate(client_data_hash)

          # build the component package
          progress "Jamf: Creating new installer pkg file '#{CLIENT_DATA_PACKAGE_FILE}'", log: :info

          unlock_signing_keychain

          component_pkg_file = build_component_client_data_pkg_file(root_dir, pkg_version, pkg_work_dir)

          build_dist_client_data_pkg_file(component_pkg_file, pkg_version, pkg_work_dir)
        end

        # Build the component install pkg with pkgbuild
        # NOTE: no need to shellescape the paths, since we are using the
        # array version of Open3.capture2e
        #
        # @return [Pathname] the path to the new package file
        #####################
        def build_component_client_data_pkg_file(root_dir, pkg_version, pkg_work_dir)
          outfile = pkg_work_dir + CLIENT_DATA_COMPONENT_PACKAGE_FILE

          cmd = ['/usr/bin/pkgbuild']
          cmd << '--root'
          cmd << root_dir.to_s
          cmd << '--identifier'
          cmd << CLIENT_DATA_PACKAGE_IDENTIFIER
          cmd << '--version'
          cmd << pkg_version
          cmd << '--install-location'
          cmd << '/'
          cmd << '--sign'
          cmd << Xolo::Server.config.pkg_signing_identity
          cmd << '--keychain'
          cmd << Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
          cmd << outfile.to_s

          log_debug "Command to build component pkg '#{CLIENT_DATA_COMPONENT_PACKAGE_FILE}': #{cmd.join(' ')}"

          stdouterr, exit_status = Open3.capture2e(*cmd)
          raise "Error creating #{CLIENT_DATA_PACKAGE_FILE}: #{stdouterr}" unless exit_status.success?

          outfile
        end

        # Build the distribution package for the xolo-client-data JSON file
        # NOTE: no need to shellescape the paths, since we are using the
        # array version of Open3.capture2e
        #
        # @return [Pathname] the path to the new package file
        #####################
        def build_dist_client_data_pkg_file(component_pkg_file, pkg_version, pkg_work_dir)
          pkg_file = pkg_work_dir + CLIENT_DATA_PACKAGE_FILE

          cmd = ['/usr/bin/productbuild']
          cmd << '--package'
          cmd << component_pkg_file.to_s
          cmd << '--identifier'
          cmd << CLIENT_DATA_PACKAGE_IDENTIFIER
          cmd << '--version'
          cmd << pkg_version
          cmd << '--sign'
          cmd << Xolo::Server.config.pkg_signing_identity
          cmd << '--keychain'
          cmd << Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
          cmd << pkg_file.to_s

          log_debug "Command to build distribution pkg '#{CLIENT_DATA_PACKAGE_FILE}': #{cmd.join(' ')}"

          stdouterr, exit_status = Open3.capture2e(*cmd)
          raise "Error creating #{CLIENT_DATA_PACKAGE_FILE}: #{stdouterr}" unless exit_status.success?

          pkg_file
        end

        # @return [Hash] the data to put in the xolo-client-data JSON file
        #####################
        def client_data_hash
          cdh = {
            titles: {}
          }
          all_title_objects.each do |title|
            cdh[:titles][title.title] = title.to_h
            cdh[:titles][title.title][:versions] = title.version_objects.map(&:to_h)

            # the client uses the version_script to determine if a title is installed
            cdh[:titles][title.title][:version_script] = title.version_script_contents if title.version_script

            # add the forced_exclusion_group_name if any
            if Xolo::Server.config.forced_exclusion
              cdh[:titles][title.title][:excluded_groups] << Xolo::Server.config.forced_exclusion
            end

            # add the frozen group name to the excluded_groups array
            cdh[:titles][title.title][:excluded_groups] << title.jamf_frozen_group_name if title.jamf_frozen_group_name
          end
          # TESTING
          # outfile = Pathname.new('/tmp/client-data.json')
          # outfile.pix_save JSON.pretty_generate(cdh)

          cdh
        end

        # @return [Pathname] the path to the client executable 'xolo' in the ruby gem
        #####################
        def client_app_source
          # parent 1 == helpers
          # parent 2 == server
          # parent 3 == xolo
          # parent 4 == lib
          # parent 5 == root
          @client_app ||= Pathname.new(__FILE__).expand_path.parent.parent.parent.parent.parent + 'data' + 'client' + 'xolo'
        end

        # temp
        #####################
        def client_data_testing
          this_file = Pathname.new(__FILE__).expand_path
          log_debug "this_file: #{this_file}"
          # parent 1 == helpers
          # parent 2 == server
          # parent 3 == xolo
          # parent 4 == lib
          # parent 5 == root
          data_dir = this_file.parent.parent.parent.parent.parent + 'data'
          log_debug "data_dir: #{data_dir}"
          log_debug "data_dir exists? #{data_dir.exist?}"
          log_debug "data_dir children: #{data_dir.children}"
          client_dir = data_dir + 'client'
          log_debug "client_dir: #{client_dir}"
          log_debug "client_dir exists? #{client_dir.exist?}"
          log_debug "client_dir children: #{client_dir.children}"
          client_app = client_dir + 'xolo'
          log_debug "client_app: #{client_app}"
          log_debug "client_app exists? #{client_app.exist?}"
        end

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
