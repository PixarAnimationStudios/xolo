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

module Xolo

  module Admin

    # Module for gathering and validating xadm options from an interactive terminal session
    module Interactive

      # Module methods
      ##############################
      ##############################

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Instance Methods
      ##########################
      ##########################

      #  Our HighLine instance
      ##############################
      def highline_cli
        @highline_cli ||= HighLine.new
      end

      # Use an interactive walkthru session to populate
      # Xolo::Admin::Options.walkthru_cmd_opts
      ###############################
      def do_walkthru
        return unless walkthru?

        # if the command doesn't take any options, there's nothing to walk through
        return if Xolo::Admin::Options::COMMANDS[cli_cmd.command][:opts].empty?

        display_walkthru_menu cli_cmd.command
      end

      #
      ##############################
      def display_walkthru_menu(cmd)
        done_with_menu = false

        # we start off with our walkthru_cmd_opts being the same
        # the same as current_opt_values
        current_opt_values.to_h.each { |k, v| walkthru_cmd_opts[k] = v }
        until done_with_menu
          # clear the screen and show the menu header
          display_walkthru_header

          # Generate the menu items
          highline_cli.choose do |menu|
            menu.select_by = :index

            menu.responses[:ambiguous_completion] = nil
            menu.responses[:no_completion] = 'Unknown Choice'

            # The menu items for setting values
            ####
            Xolo::Admin::Options::COMMANDS[cmd][:opts].each do |key, deets|
              curr_val = current_opt_values[key]
              new_val = walkthru_cmd_opts[key]
              not_avail = send(deets[:walkthru_na]) if deets[:walkthru_na]
              menu_item = menu_item_text(deets[:label], old: curr_val, new: new_val, not_avail: not_avail)

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
                menu.choice(nil, nil, menu_item) { prompt_for_walkthru_value key, deets, curr_val }
              end
            end

            # always show 'Cancel' in the same position
            menu.choice(nil, nil, 'Cancel') do
              done_with_menu = true
              @walkthru_cancelled = true
            end

            # check for any required values missing or if
            # there's internal inconsistency between given values
            still_needed = missing_values
            consistency_error = internal_consistency_error

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
      ##############################
      def version_script_na
        return if !current_opt_values[:app_name] && \
                  !current_opt_values[:app_bundle_id] && \
                  !walkthru_cmd_opts[:app_name] && \
                  !walkthru_cmd_opts[:app_bundle_id]

        'N/A when using App Name/BundleID'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def app_name_bundleid_na
        return if !current_opt_values[:version_script] && \
                  !walkthru_cmd_opts[:version_script]

        'N/A when using Version Script'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def ssvc_na
        all = Xolo::Admin::Title::TARGET_ALL
        tgt_all = current_opt_values[:target_groups]&.include?(all) || \
                  walkthru_cmd_opts[:target_groups]&.include?(all)

        "N/A if Target Group is '#{all}'" if tgt_all
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def pw_na
        admin_empty = walkthru_cmd_opts[:admin].to_s.empty?
        host_empty = walkthru_cmd_opts[:hostname].to_s.empty?
        'N/A until hostname and admin name are set' if host_empty || admin_empty
      end

      # @return [String, nil] any current internal consistency error. will be nil when none remain
      ##############################
      def internal_consistency_error
        validate_internal_consistency walkthru_cmd_opts
        nil
      rescue Xolo::InvalidDataError => e
        e.to_s
      end

      # The menu header
      ##############################
      def display_walkthru_header
        header_text = Xolo::Admin::Options::COMMANDS[cli_cmd.command][:walkthru_header].dup
        return unless header_text

        header_text.sub! Xolo::Admin::Options::TARGET_TITLE_PLACEHOLDER, cli_cmd.title if cli_cmd.title
        header_text.sub! Xolo::Admin::Options::TARGET_VERSION_PLACEHOLDER, cli_cmd.version if cli_cmd.version

        header_sep_line = Xolo::DASH * header_text.length

        system 'clear'
        puts <<~ENDPUTS
          #{header_sep_line}
          #{header_text}
          #{header_sep_line}
          Current Settings => New Settings

        ENDPUTS
      end

      ##################################
      def menu_item_text(lbl, old: nil, new: nil, not_avail: nil)
        txt = "#{lbl}:"
        return "#{txt} ** #{not_avail}" if not_avail

        txt = "#{txt} #{old}".strip
        return txt if old == new

        "#{txt} => #{new}"
      end

      # prompt for and return a value
      ##############################
      def prompt_for_walkthru_value(key, deets, curr_val)
        default = default_for_value(key, deets, curr_val)
        question = question_for_value(deets)
        q_desc = question_desc(deets, default)

        # Highline wants a separate lambda for conversion
        # and validation, validation just returns boolean,
        # but conversion returns the converted value.
        # but our validation methods do the conversion.
        #
        # so we'll just return the last_converted_value we got
        # when we validate, or nil if we don't validate
        #
        validate = valdation_lambda(key, deets)
        convert = validate ? ->(_ans) { last_converted_value } : ->(ans) { ans }

        answer = highline_cli.ask(question, convert) do |q|
          q.default = default
          # q.readline = true # allows tab-completion of filenames, and using arrow keys

          q.echo = '*' if deets[:secure_interactive_input]

          if validate
            q.validate = validate

            not_valid_response = ->(_x) { "\nERROR: #{last_validation_error}".pix_word_wrap }
            # not_valid_response ||= "\nERROR: #{deets[:invalid_msg]}"
            # not_valid_response << " Cannot be unset with 'none'." if deets[:required]
            # not_valid_response = not_valid_response.pix_word_wrap
            q.responses[:not_valid] = not_valid_response

            not_valid_re_ask = +"Enter #{deets[:label]}: "
            not_valid_re_ask << "|#{default}| " if default
            q.responses[:ask_on_error] = not_valid_re_ask
          end

          # display a description of the value being asked for
          highline_cli.say q_desc
        end
        return if answer.pix_blank?

        answer = nil if answer == Xolo::NONE

        walkthru_cmd_opts[key] = answer
      end # prompt for value

      # The 'default' value for the highline question
      # when prompting for a value
      ##############################
      def default_for_value(key, deets, curr_val)
        # default is the current value, or the
        # defined value if no current.
        default = walkthru_cmd_opts[key] || curr_val || deets[:default]
        default = default.join(', ') if default.is_a? Array
        default
      end

      # The multi-lines of text describing the value above the prompt
      ##############################
      def question_desc(deets, default)
        q_desc = +"============= #{deets[:label]} =============\n"
        q_desc << deets[:desc]
        q_desc << "\nType a return for default value '#{default}'" if default
        q_desc << "\n"
        q_desc
      end

      # The line of text prompting for a value.
      ##############################
      def question_for_value(deets)
        question = +"Enter #{deets[:label]}"

        if deets[:type] == :boolean
          question << ', (y/n)'
        elsif !deets[:required]
          question << ", '#{Xolo::NONE}' to unset"
        end
        question << ':'
        question = question.pix_word_wrap
        question.chomp # + ' '
      end

      # Retun a lambda that calls one of our validation methods to validate
      # a walkthru value.
      #
      # Highlight requires validation lambdas to return a boolean, and uses
      # a separate lambda for type conversion.
      # Since our validation methods do both, this lambda will put the converted
      # result into the 'last_converted_value' accessor, or capture the error,
      # and then return a boolean.
      #
      # Later the lambda we give to highline for conversion will just return
      # the last converted value, as stored in the last_converted_value accessor.
      #
      # @return [Lambda, nil] The lambda that highline will use to validate
      #    (and convert) a value, nil if we accept whatever was given.
      #
      ##############################
      def valdation_lambda(key, deets)
        val_meth = valdation_method(key, deets)
        return unless val_meth

        # lambda to validate the value given.
        # must return boolean for Highline to deal with it.
        lambda do |ans|
          # default to the pre-written error message
          self.last_validation_error = deets[:invalid_msg]

          # to start, the converted value is just the given value
          # use self. here, otherwise the lambda sees last_converted_value
          # as a local variable
          self.last_converted_value = ans

          # if user just hit return, nothing to validate,
          # the current/default value will remain.
          return true if ans.pix_blank?

          # If this value isn't required, accept 'none'
          if !deets[:required] && (ans == Xolo::NONE)
            self.last_converted_value = Xolo::NONE
            return true
          end

          # otherwise 'none' becomes nil and will be validated
          ans_to_validate = ans == Xolo::NONE ? nil : ans

          # split comma-sep. multi values
          # TODO: investigate highline multi/array input
          ans_to_validate = ans_to_validate.split(Xolo::COMMA_SEP_RE) if deets[:multi]

          # save the validated/converted value for use in the
          # convert method. so we don't have to call the validate method
          # twice
          self.last_converted_value = (send val_meth, ans_to_validate)
          true
        rescue Xolo::InvalidDataError => e
          self.last_validation_error = e.to_s
          false
        end # lambda
      end

      # getter/setter for the value converted by the last validation
      # method call - we do this so the same value is available in the
      #  convert and validate lambdas
      ##############################
      attr_accessor :last_converted_value

      # getter/setter for the value converted by the last validation
      # method call - we do this so the same value is available in the
      #  convert and validate lambdas
      ##############################
      attr_accessor :last_validation_error

      # The method used to validate and convert a value
      ##############################
      def valdation_method(key, deets)
        case deets[:validate]
        when TrueClass then "validate_#{key}"
        when Symbol then deets[:validate]
        end
      end

      ##################################
      def missing_values
        missing_values = []
        required_values.each do |key, deets|
          next if walkthru_cmd_opts[key]

          missing_values << deets[:label]
        end
        missing_values
      end

    end # module Interactive

  end # module Admin

end # module Xolo
