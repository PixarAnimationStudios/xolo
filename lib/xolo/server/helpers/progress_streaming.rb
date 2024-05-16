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

      # This is used both as a 'helper' in the Sinatra server,
      # and an included mixin for the Xolo::Server::Title and
      # Xolo::Server::Version classes
      # to provide common methods for long-running routes that deliver
      # realtime progress updates via http streaming.
      module ProgressStreaming

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
        #######################

        # Call this from long-running routes.
        #
        # It runs a block in a thread with streaming
        #
        # The block should call #progress as needed to write
        # to the progress file, and optionally the log
        #
        # Always sends back a JSON response body with
        # {
        #   status: :running,
        #   progress_stream_url_path: progress_stream_url_path
        # }
        # Any errors should be written to the stream file,
        # as will unhandled exceptions.
        #
        # @yield The block to run in the thread with streaming
        ##########################
        def with_streaming
          raise 'No block given to run in streaming thread' unless block_given?

          # always call this first in a
          # long-running route that will use progress streaming
          setup_progress_streaming

          log_debug 'Starting with_streaming block in thread'

          @streaming_thread = Thread.new do
            yield
            log_debug 'Thread with_streaming is finished'
          rescue StandardError => e
            progress "ERROR: #{e.class}: #{e}", log: :error
          ensure
            stop_progress_streaming
          end

          @streaming_thread.name = "xolo-progress-stream-#{session[:xolo_id]}"

          resp_body = {
            status: :running,
            progress_stream_url_path: progress_stream_url_path
          }
          body resp_body
        end

        # Setup for streaming:
        # create the tmp file so that any threads will see it
        # and do any other pre-streaming stuff
        #
        # @param xadm_command [String] the xadm command that is causing this stream.
        #   may be used for finding a returning the progress file after the fact.
        #
        ##########################
        def setup_progress_streaming
          log_debug "Setting up for progress streaming. progress_stream_file is: #{progress_stream_file}"
        end

        # End che current progress stream
        ###############################
        def stop_progress_streaming
          progress Xolo::Server::PROGRESS_COMPLETE
        end

        # The file to which we write progess messages
        # for long-running processes, which might in turn
        # be streamed to xadm.
        #
        # @param command [String] the xadm command that is causing this stream.
        #   may be used for finding a returning the progress file after the fact.
        #
        #############################
        def progress_stream_file
          return @progress_stream_file if @progress_stream_file

          tempf = Tempfile.create "xolo-progress-stream-#{session[:xolo_id]}-"
          tempf.close # we'll write to it later
          log_debug "Created progress_stream_file: #{tempf.path}"
          @progress_stream_file = Pathname.new(tempf.path)
        end

        # The file to which we write progess messages
        # for long-running processes, which might in turn
        # be streamed to xadm.
        #############################
        def progress_stream_url_path
          "/streamed_progress/?stream_file=#{CGI.escape progress_stream_file.to_s}"
        end

        # Append a message to the progress stream file,
        # optionally sending it also to the log
        #
        # @param message [String] the message to append
        # @param log [Symbol] the level at which to log the message
        #   one of :debug, :info, :warn, :error, :fatal, or :unknown.
        #   Default is nil, which doesn't log the message at all.
        #
        # @return [void]
        ###################
        def progress(msg, log: :debug)
          progress_stream_file.pix_append "#{msg.chomp}\n"

          unless log
            log_debug 'Processed unlogged progress message'
            return
          end

          case log
          when :debug
            log_debug msg
          when :info
            log_info msg
          when :warn
            log_warn msg
          when :error
            log_error msg
          when :fatal
            log_fatal msg
          when :unknown
            log_unknown msg
          end
        end

        # Stream lines from the given file to the given stream
        #
        # @param stream_file: [Pathname] the file to stream from
        # @param stream:  [Sinatra::Helpers::Stream] the stream to send to
        #
        # @return [void]
        #############################
        def stream_progress(stream_file:, stream:)
          log_debug "About to tail: usr/bin/tail -f -c +1 #{Shellwords.escape stream_file.to_s}"

          stdin, stdouterr, wait_thr = Open3.popen2e("/usr/bin/tail -f -c +1 #{Shellwords.escape stream_file.to_s}")
          stdin.close

          while line = stdouterr.gets
            break if line.chomp == Xolo::Server::PROGRESS_COMPLETE

            stream << line
          end
          stdouterr.close
          wait_thr.exit
          # TODO: deal with wait_thr.value.exitstatus > 0 ?
        end

        # TEMP TESTING  - Thisis happening in a thread and
        # should send updates via #progress
        #
        ######################
        def a_long_thing_with_streamed_feedback
          log_debug 'Starting a_long_thing_with_streamed_feedback'

          progress 'Doing a quick thing...'
          sleep 3
          progress 'Quick thing done.'

          progress "Doing a slow thing at #{Time.now}  ..."
          log_debug 'Starting thread in a_long_thing_with_streamed_feedback'

          # even tho we are in a thread, if we want to
          # send updates while some long sub-task is running
          # we do it in another thread like this
          long_thr = Thread.new { sleep 30 }
          sleep 3

          while long_thr.alive?
            log_debug 'Thread still alive...'
            progress "Slow thing still happening at #{Time.now} ..."
            sleep 3
          end

          log_debug 'Thread in a_long_thing_with_streamed_feedback is done'

          progress 'Slow thing done.'

          progress "Doing a medium thing at #{Time.now}  ..."
          log_debug 'Starting another thread in a_long_thing_with_streamed_feedback - sends output from the thread'

          # Doing this in a thead is just for academics...
          # as is doing anything in a thread and immediately doing thr.join
          med_thr = Thread.new do
            3.times do |x|
              progress "the medium thing has done #{x + 1} things", log: :debug
              sleep 5
            end
          end

          progress 'Now waiting for medium thing to finish...'
          med_thr.join

          progress 'Medium thing is done.'
        end

        ########## TMP
        def jsonify_stream_msg(msg)
          @out_to_stream << { msg: msg }.to_json
        end

      end # Streaming

    end # Helpers

  end # Server

end # module Xolo
