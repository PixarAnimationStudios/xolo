# Copyright 2023 Pixar
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

require 'highline'

module Xolo

  module Admin

    # Module for gathering and validating xadm options from an interactive terminal session
    module Interactive

      #  Our HighLine instance
      def self.cli
        @cli ||= HighLine.new
      end

      # Use an interactive walkthru session to populate
      # Xolo::Admin::Options.cli_cmd_opts
      #
      def self.walkthru
        cmd = Xolo::Admin::Options.cli_cmd.command

        return unless Xolo::Admin::Options.global_opts.walkthru
        # if the command doesn't take any options, there's nothing to walk through
        return if Xolo::Admin::Options::COMMANDS[cmd][:opts].empty?

        display_walkthru_menu cmd
      end

      ####
      def self.display_walkthru_menu(cmd)
        done_with_menu = false

        # we start off with our Xolo::Admin::Options.walkthru_cmd_opts being the same
        # the same as Xolo::Admin::Options.current_opt_values
        Xolo::Admin::Options.current_opt_values.to_h.each { |k, v| Xolo::Admin::Options.walkthru_cmd_opts[k] = v }

        # as the current_values
        until done_with_menu
          # clear the screen and show the menu header
          display_walkthru_header

          # Generate the menu items
          cli.choose do |menu|
            menu.responses[:ambiguous_completion] = nil
            menu.responses[:no_completion] = 'Unknown Choice'

            # The menu items for setting values
            ####
            Xolo::Admin::Options::COMMANDS[cmd][:opts].each do |key, deets|
              curr_val = Xolo::Admin::Options.current_opt_values[key]
              new_val = Xolo::Admin::Options.walkthru_cmd_opts[key]
              not_avail = send(deets[:walkthru_na]) if deets[:walkthru_na]
              menu_item = menu_item_text(deets[:label], old: curr_val, new: new_val, not_avail: not_avail)

              # no processing if item not available

              # with menu.choice, the first arg is the 'name' which is used for text-based
              # menu choosing, and we want number-based, so set it to nil.
              # Second arg is 'help' which is not used unless the menu is a 'shell'
              # menu
              # third arg is 'text' which is the text of the menu item, and if left
              # out, the 'name' is used.
              # HighLine should really use keyword args for these, and prob will
              # eventually.

              # no processing if item not available
              if not_avail
                menu.choice(nil, nil, menu_item) {}
              else
                menu.choice(nil, nil, menu_item) { prompt_for_value key, deets, curr_val }
              end
            end

            # check for any required values missing or if
            # there's internal inconsistency between given values
            still_needed = missing_values
            consistency_error = internal_consistency_error

            # always show 'Cancel' in the same position
            menu.choice(nil, nil, 'Cancel') do
              done_with_menu = true
              @cancelled = true
            end

            # only show 'done' when all required values are there and
            # consistency is OK
            menu.choice(nil, nil, 'Done') { done_with_menu = true } if still_needed.empty? && consistency_error.nil?

            # The prompt will include info about required values and consistency
            prompt = ''
            prompt = "#{prompt}\n- Missing: #{still_needed.join ', '}" unless still_needed.empty?
            prompt = "#{prompt}\n- #{consistency_error}" if consistency_error
            prompt = "#{prompt}\nYour Choice: "
            menu.prompt = prompt
          end

        end # until done with menu
      end # def self.display_title_menu(_title)

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      def self.version_script_na
        return if !Xolo::Admin::Options.current_opt_values[:app_name] && \
                  !Xolo::Admin::Options.current_opt_values[:app_bundle_id] && \
                  !Xolo::Admin::Options.walkthru_cmd_opts[:app_name] && \
                  !Xolo::Admin::Options.walkthru_cmd_opts[:app_bundle_id]

        'N/A when using App Name/BundleID'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      def self.app_name_bundleid_na
        return if !Xolo::Admin::Options.current_opt_values[:version_script] && \
                  !Xolo::Admin::Options.walkthru_cmd_opts[:version_script]

        'N/A when using Version Script'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      def self.ssvc_na
        all = Xolo::Admin::Title::TARGET_ALL
        tgt_all = Xolo::Admin::Options.current_opt_values[:target_groups]&.include?(all) || \
                  Xolo::Admin::Options.walkthru_cmd_opts[:target_groups]&.include?(all)

        return "N/A if Target Group is '#{all}'" if tgt_all
      end

      # @return [String, nil] any current internal consistency error. will be nil when none remain
      def self.internal_consistency_error
        Xolo::Admin::Validate.internal_consistency Xolo::Admin::Options.walkthru_cmd_opts
        nil
      rescue Xolo::InvalidDataError => e
        e.to_s
      end

      # The menu header
      def self.display_walkthru_header
        header_action = Xolo::Admin::CommandLine.add_command? ? 'Adding' : 'Editing'
        header_target = "Xolo title '#{Xolo::Admin::Options.cli_cmd.title}'"
        if Xolo::Admin::CommandLine.version_command?
          header_target = "Version #{Xolo::Admin::Options.cli_cmd.version} of #{header_target}"
        end
        header_text = "#{header_action} #{header_target}"
        header_sep_line = Xolo::DASH * header_text.length

        system 'clear'
        puts <<~ENDPUTS
          #{header_sep_line}
          #{header_action} #{header_target}
          #{header_sep_line}
          Current Settings => New Settings

        ENDPUTS
      end

      ####
      def self.menu_item_text(lbl, old: nil, new: nil, not_avail: nil)
        txt = "#{lbl}:"
        return "#{txt} ** #{not_avail}" if not_avail

        txt = "#{txt} #{old}".strip
        return txt if old == new

        "#{txt} => #{new}"
      end

      #### prompt for and return a value
      def self.prompt_for_value(key, deets, curr_val)
        default = default_for_value(key, deets, curr_val)
        question = question_for_value(deets)

        # Highline wants a separate proc for conversion
        # so we'll just return the converted_value we got
        # when we validate, or nil if we don't validate
        Xolo::Admin::Interactive.converted_value = nil
        convert = ->(_ans) { Xolo::Admin::Interactive.converted_value }

        validate = valdation_lambda(key, deets)

        answer = cli.ask(question, convert) do |q|
          q.default = default
          q.readline = deets[:readline]

          if validate
            q.validate = validate
            not_valid_response = +"\nERROR: #{deets[:invalid_msg]}"
            not_valid_response << " Cannot be unset with 'none'." if deets[:required]
            not_valid_response = not_valid_response.pix_word_wrap
            q.responses[:not_valid] = not_valid_response
            not_valid_re_ask = +"Enter #{deets[:label]}: "
            not_valid_re_ask << "|#{default}| " if default
            q.responses[:ask_on_error] = not_valid_re_ask
          end
        end

        return if answer.to_s.empty?

        answer = nil if answer == Xolo::NONE
        Xolo::Admin::Options.walkthru_cmd_opts[key] = answer
      end # prompt for value

      # The 'default' value for the highline question
      # when prompting for a value
      def self.default_for_value(key, deets, curr_val)
        # default is the current value, or the
        # defined value if no current.
        default = Xolo::Admin::Options.walkthru_cmd_opts[key] || curr_val || deets[:default]
        default = default.join(', ') if default.is_a? Array
        default
      end

      # The text displayed when prompting for a value.
      def self.question_for_value(deets)
        question = +"============= #{deets[:label]} =============\n"
        question << deets[:desc]
        question << "\n"
        question << "Enter #{deets[:label]}"

        if deets[:type] == :boolean
          question << ', (y/n)'
        elsif !deets[:required]
          question << ", '#{Xolo::NONE}' to unset"
        end
        question << ':'
        question = question.pix_word_wrap
        question.chomp + ' '
      end

      # The lambda that highline will use to validate
      # (and convert) a value
      def self.valdation_lambda(key, deets)
        val_meth = valdation_method(key, deets)
        return unless val_meth

        Xolo::Admin::Interactive.converted_value = nil

        # lambda to validate the value given.
        # must return boolean for Highline to deal with it.
        lambda do |ans|
          # if user just hit return, nothing to validate,
          # the current/default value will remain.
          return true if ans.to_s.empty?

          # If this value isn't required, accept 'none'
          if !deets[:required] && (ans == Xolo::NONE)
            Xolo::Admin::Interactive.converted_value = Xolo::NONE
            return true
          end

          # otherwise 'none' becomes nil and will be validated
          ans_to_validate = ans == Xolo::NONE ? nil : ans

          # split comma-sep. multi values
          ans_to_validate = ans_to_validate.split(Xolo::COMMA_SEP_RE) if deets[:multi]

          # save the validated/converted value for use in the
          # convert method. so we don't have to call the validate method
          # twice
          Xolo::Admin::Interactive.converted_value = Xolo::Admin::Validate.send val_meth, ans_to_validate

          true
        rescue Xolo::InvalidDataError
          false
        end
      end

      # getter/setter for the value converted by the last validation
      # method call - we do this so the same value is available in the
      #  convert and validate lambdas

      def self.converted_value=(val)
        @converted_value = val
      end

      def self.converted_value
        @converted_value
      end

      # The method used to validate and convert a value
      def self.valdation_method(key, deets)
        case deets[:validate]
        when TrueClass then key
        when Symbol then deets[:validate]
        end
      end

      ####
      def self.missing_values
        missing_values = []
        Xolo::Admin::Options.required_values.each do |key, deets|
          # next if Xolo::Admin::Options.cli_cmd_opts[key]
          next if Xolo::Admin::Options.walkthru_cmd_opts[key]

          missing_values << deets[:label]
        end
        missing_values
      end

    end # module Interactive

  end # module Admin

end # module Xolo
