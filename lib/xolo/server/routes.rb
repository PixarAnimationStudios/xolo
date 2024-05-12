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

# frozen_string_literal: true

# main module
module Xolo

  # Server Module
  module Server

    module Routes

      # This is how we 'mix in' modules to Sinatra servers:
      # We make them extentions here with
      #    extend Sinatra::Extension (from sinatra-contrib)
      # and then 'register' them in the server with
      #    register Xolo::Server::<Module>
      # Doing it this way allows us to split the code into a logical
      # file structure, without re-opening the Sinatra::Base server app,
      # and let xeitwork do the requiring of those files
      extend Sinatra::Extension

      # pre-process
      ##############
      before do
        adm = session[:admin] ? ", admin '#{session[:admin]}'" : Xolo::BLANK
        log_info "Processing #{request.request_method} #{request.path} from #{request.ip}#{adm}"

        # these routes don't need an auth'd session
        break if Xolo::Server::Helpers::Auth::NO_AUTH_ROUTES.include? request.path
        break if Xolo::Server::Helpers::Auth::NO_AUTH_PREFIXES.any? { |pfx| request.path.start_with? pfx }

        # If here, we must have a session cookie marked as 'authenticated'
        # log_debug "Session in before filter: #{session.inspect}"

        halt 401, { error: 'You must log in to the Xolo server' } unless session[:authenticated]
      end

      # post-process
      ##############
      after do
        if @no_json
          log_debug 'NOT converting body to JSON in after filter'
        else
          log_debug 'Converting body to JSON in after filter'
          content_type :json
          # IMPORTANT, this only works if you remember to explicitly use
          # `body body_content` in every route.
          # You can't just define the body
          # by the last evaluated statement of the route.
          #
          response.body = JSON.dump(response.body)
        end
      end

      # error process
      ##############
      error do
        log_debug 'Running error filter'

        body({ status: response.status, error: env['sinatra.error'].message })
      end

      # Ping
      ##########
      get '/ping' do
        @no_json = true
        body 'pong'
      end

      # Threads
      ##########
      get '/threads' do
        body Xolo::Server.thread_info
      end

      # State
      ##########
      get '/state' do
        state = {
          executable: Xolo::Server::EXECUTABLE_FILENAME,
          start_time: Xolo::Server.start_time,
          app_env: Xolo::Server.app_env,
          data_dir: Xolo::Server::DATA_DIR,
          log_file: Xolo::Server::Log::LOG_FILE,
          log_level: Xolo::Server::Log::LEVELS[Xolo::Server.logger.level],
          xolo_version: Xolo::VERSION,
          ruby_jss_version: Jamf::VERSION,
          windoo_version: Windoo::VERSION,
          config: Xolo::Server.config.to_h_private,
          threads: Xolo::Server.thread_info
        }

        body state
      end

      # test
      ##########
      get '/test' do
        ##### UNLOCK KEYCHAIN
        pw = Xolo::Server.config.pkg_signing_keychain_pw
        # first escape backslashes
        pw = pw.to_s.gsub '\\', '\\\\\\'
        # then single quotes
        pw.gsub! "'", "\\\\'"
        # then warp in sgl quotes
        pw = "'#{pw}'"

        output = Xolo::BLANK
        errs = Xolo::BLANK
        exit_status = nil
        Open3.popen3('/usr/bin/security -i') do |stdin, stdout, stderr, wait_thr|
          # pid = wait_thr.pid # pid of the started process.
          stdin.puts "unlock-keychain -p #{pw} '#{Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN}'"
          stdin.close

          output = stdout.read
          errs = stderr.read

          exit_status = wait_thr.value # Process::Status object returned.
        end # Open3.popen3

        tempfile = Pathname.new '/tmp/chrisltest-unsigned.pkg'
        pkg_to_upload = Pathname.new '/tmp/chrisltest-xolo-signed.pkg'

        sh_kch = Shellwords.escape Xolo::Server::Configuration::PKG_SIGNING_KEYCHAIN.to_s
        sh_tmpf = Shellwords.escape tempfile.to_s
        sh_upf = Shellwords.escape pkg_to_upload.to_s
        sh_ident = Shellwords.escape Xolo::Server.config.pkg_signing_identity

        cmd = "/usr/bin/productsign --sign #{sh_ident} --keychain #{sh_kch} #{sh_tmpf} #{sh_upf}"
        log_debug "running: #{cmd}"

        out, err, sta = Open3.capture3(cmd)

        #### CHECK SIGNED
        sign_worked = system "/usr/sbin/pkgutil --check-signature #{Shellwords.escape pkg_to_upload.to_s}"

        response_body = {
          out: out,
          err: err,
          status: sta.exitstatus,
          relockout: relockout,
          sign_worked: sign_worked
        }
        body response_body
      end

    end #  Routes

  end #  Server

end # module Xolo
