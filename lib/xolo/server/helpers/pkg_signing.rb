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

      # constants and methods for signing packages
      module PkgSigning

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

        # do we need to sign a pkg?
        # TODO: sign zipped bundle installers? prob not, they shouldn't be used anymore
        # (I'm looking at YOU Adobe)
        # @param pkg [Pathname] Path to a .pkg to see if it's signed.
        # @return [Boolean] should we sign it?
        def need_to_sign?(pkg)
          log_debug "Checking need to sign uploaded pkg '#{pkg}'"
          unless Xolo::Server.config.sign_pkgs
            log_debug "No need to sign '#{pkg.basename}': xolo server is not configured to sign pkgs."
            return false
          end
          if pkg.extname == Xolo::DOT_ZIP
            log_debug "No need to sign '#{pkg.basename}': It is a compressed .pkg bundle. TODO: maybe support signing these?"
            return false
          end

          !pkg_signed?(pkg)
        end

        # @param pkg [Pathname] Path to a .pkg to see if it's already signed.
        # @return [Boolean] is then pkg at the given pathname signed?
        #########################
        def pkg_signed?(pkg)
          `/usr/sbin/pkgutil --check-signature #{Shellwords.escape pkg.to_s}`
          already_signed = $CHILD_STATUS.success?
          if already_signed
            log_debug "No need to sign '#{pkg.basename}': It is already signed."
          else
            log_debug "About to sign '#{pkg.basename}'"
          end
          already_signed
        end

        # Sign a package
        #
        # @param unsigned_pkg [Pathname] the unsigned pkg to sign
        # @param signed_pkg [Pathname] the destination file to write the signed version of the pkg.
        #
        # @return [void]
        #######################################################
        def sign_uploaded_pkg(unsigned_pkg, signed_pkg)
          unlock_signing_keychain

          sh_unsigned = Shellwords.escape unsigned_pkg.to_s
          sh_signed = Shellwords.escape signed_pkg.to_s
          sh_kch = Shellwords.escape Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
          sh_ident = Shellwords.escape Xolo::Server.config.pkg_signing_identity

          cmd = "/usr/bin/productsign --sign #{sh_ident} --keychain #{sh_kch} #{sh_unsigned} #{sh_signed}"
          log_debug "Signing #{signed_pkg.basename} using this command: #{cmd}"

          stdouterr, exit_status = Open3.capture2e(cmd)
          return if exit_status.success?

          msg = "Failed to sign uploaded pkg: #{stdouterr}"
          log_error msg
          halt 400, { error: msg }
        end

        # unlock the pkg signing keychain
        # TODO: Be DRY with the keychain stuff in Xolo::Admin::Credentials
        #############################
        def unlock_signing_keychain
          log_debug 'Unlocking the signing keychain'

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

      end # JamfPro

    end # Helpers

  end # Server

end # module Xolo
