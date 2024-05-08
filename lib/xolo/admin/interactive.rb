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

      # Constants
      ###########################
      ###########################

      MULTILINE_EDITORS = {
        'vim (vi)' => '/usr/bin/vim',
        'mg (emacs)' => '/usr/bin/mg',
        'pico (nano)' => '/usr/bin/pico'
      }

      MULTILINE_HEADER_SEPARATOR = "\nDO NOT EDIT anything above the next line:\n=================================="

      DEFAULT_HIGHLINE_READLINE_PROMPT = 'Enter value'

      HIGHLINE_READLINE_GATHER_ERR_INSTRUCTIONS = <<~ENDINSTR
        Use tab for auto-completion, tab twice to see available choices
        Type '#{Xolo::X}' to exit."
      ENDINSTR

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

      # @return [Integer] how many rows high is our terminal?
      #########################
      def terminal_height
        IO.console.winsize.first
      end

      # @return [Integer] how many columns wide is our terminal?
      #########################
      def terminal_width
        IO.console.winsize.last
      end

      # @return [Integer] how wide is our word wrap? terminal-width minus 5
      #########################
      def terminal_word_wrap
        @terminal_word_wrap ||= terminal_width - 5
      end

      # @return [Highline] Our HighLine instance.
      #    Word wrap at terminal-width minus 5
      ##############################
      def highline_cli
        return @highline_cli if @highline_cli

        @highline_cli ||= HighLine.new
        @highline_cli.wrap_at = terminal_word_wrap
        @highline_cli
      end

      # Use an interactive walkthru session to populate
      # Xolo::Admin::Options.walkthru_cmd_opts
      # @return [void]
      ###############################
      def do_walkthru
        return unless walkthru?

        # only one readline thing per line
        Readline.completion_append_character = nil
        # all chars are allowed in readline choices
        Readline.basic_word_break_characters = "\n"

        # if the command doesn't take any options, there's nothing to walk through
        return if Xolo::Admin::Options::COMMANDS[cli_cmd.command][:opts].empty?

        display_walkthru_menu
      end

      # Build and display the walkthru menu for the given command
      # @return [void]
      ##############################
      def display_walkthru_menu
        cmd = cli_cmd.command
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
            cmd_details(cmd)[:opts].each do |key, deets|
              curr_val = current_opt_values[key]
              new_val = walkthru_cmd_opts[key]
              not_avail = send(deets[:walkthru_na]) if deets[:walkthru_na]
              menu_item = menu_item_text(deets[:label], oldval: curr_val, newval: new_val, not_avail: not_avail)

              # no processing if item not available
              if not_avail
                # menu.choice(nil, nil, menu_item) {}
                menu.choice(menu_item) {}
              else
                # menu.choice(nil, nil, menu_item) { prompt_for_walkthru_value key, deets, curr_val }
                menu.choice(menu_item) { prompt_for_walkthru_value key, deets, curr_val }
              end
            end

            # always show 'Cancel' in the same position
            menu.choice(Xolo::CANCEL) do
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
            prompt = Xolo::BLANK
            prompt = "#{prompt}\n- Missing: #{still_needed.join Xolo::COMMA_JOIN}" unless still_needed.empty?
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
        return unless walkthru_cmd_opts[:app_name] || walkthru_cmd_opts[:app_bundle_id]

        'N/A when using App Name/BundleID'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def app_name_bundleid_na
        return unless walkthru_cmd_opts[:version_script]

        'N/A when using Version Script'
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def ssvc_na
        tgt_all = walkthru_cmd_opts[:target_groups]&.include?(Xolo::Admin::Title::TARGET_ALL)

        "N/A if Target Group is '#{Xolo::Admin::Title::TARGET_ALL}'" if tgt_all
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def expiration_na
        'N/A unless expiration is > 0' unless walkthru_cmd_opts[:expiration].to_i.positive?
      end

      # @return [String, nil] If a string, a reason why the given menu item is not available now.
      #   If nil, the menu item is displayed normally.
      ##############################
      def pw_na
        admin_empty = walkthru_cmd_opts[:admin].pix_blank?
        host_empty = walkthru_cmd_opts[:hostname].pix_blank?
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

      # Clear the terminal window and display the menu header above the highline menu
      # @return [void]
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

      # @param lbl [String] the label to use at the start of the text
      #   e.g. 'Description'
      # @param oldval [Object] the original value before we started doing
      #   whatever we are doing
      # @param newval [Object] the latest value that was entered by the user
      # @param not_avail [String] if the menu item is unavailable, this
      #   expalins why.
      # @return [String] the menu item text
      ##################################
      def menu_item_text(lbl, oldval: nil, newval: nil, not_avail: nil)
        oldval = oldval.join(Xolo::COMMA_JOIN) if oldval.is_a? Array
        newval = newval.join(Xolo::COMMA_JOIN) if newval.is_a? Array

        txt = "#{lbl}:"
        return "#{txt} ** #{not_avail}" if not_avail

        txt = "#{lbl}: #{oldval}"
        txt = "#{lbl}:\n#{oldval}\n" if txt.length >= terminal_word_wrap
        return txt if oldval == newval

        txt = "#{lbl}: #{oldval} -> #{newval}"
        txt = "#{lbl}:\n#{oldval}\n  ->\n#{newval}\n" if txt.length >= terminal_word_wrap
        txt
      end

      # prompt for an option value and store it in walkthru_cmd_opts
      #
      # @param key [Symbol] One of the keys of the opts hash for the current command;
      #   the value for which we are prompting
      # @param deets [Hash] the details about the option key we prompting for
      # @param curr_val [Object] The current value of the option, if any
      #
      # @return [void]
      ##############################
      def prompt_for_walkthru_value(key, deets, _curr_val)
        # current_value = default_for_value(key, deets, curr_val) # Needed??
        current_value = walkthru_cmd_opts[key]
        q_desc = question_desc(deets)
        question = question_for_value(deets)

        # Highline wants a separate lambda for conversion
        # and validation, validation just returns boolean,
        # but conversion returns the converted value.
        # but our validation methods do the conversion.
        #
        # so we'll just return the last_converted_value we got
        # when we validate, or nil if we don't validate
        #
        validate = validation_lambda(key, deets)
        convert = validate ? ->(_ans) { last_converted_value } : ->(ans) { ans }

        answer =
          if deets[:multiline]
            prompt_via_multiline_editor(
              question: question,
              q_desc: q_desc,
              current_value: current_value,
              validate: validate
            )
          elsif deets[:readline] == :get_files
            prompt_for_local_files_via_readline(
              question: question,
              q_desc: q_desc,
              deets: deets,
              validate: validate
            )
          elsif deets[:multi]
            prompt_for_multi_values_with_highline(
              question: question,
              q_desc: q_desc,
              deets: deets,
              convert: convert,
              validate: validate
            )
          else
            prompt_for_single_value_with_highline(
              question: question,
              q_desc: q_desc,
              convert: convert,
              validate: validate,
              deets: deets
            )
          end

        # answer = answer.map(&:strip).join("\n") if deets[:multiline]
        # x means keep the current value
        # answer = nil if answer == 'x'

        # if no answer, keep the current value
        return if answer.pix_blank?

        # if 'none', erase the value in walkthru_cmd_opts
        answer = nil if answer == Xolo::NONE

        walkthru_cmd_opts[key] = answer
      end # prompt for value

      # Prompt for a one-line single value via highline, possibly with
      # readline auto-completion from an array of possible values
      #
      # @param question [String] The question to ask
      # @param q_desc [String] A longer description of what we're asking for
      # @param convert [Lambda] The lambda for converting the validated value
      # @param validate [Lambda] The lambda for validating the answer before conversion
      # @param deets [Hash] The option-details for the value for which we are prompting
      #
      # @return [Object] The validated and converted value given by the user.
      ###############################
      def prompt_for_single_value_with_highline(question:, q_desc:, convert:, validate:, deets:)
        use_readline, convert, validate = setup_for_readline_in_highline(deets, convert, validate)

        highline_cli.say q_desc

        highline_cli.ask(question, convert) do |q|
          q.readline = use_readline
          q.echo = '*' if deets[:secure_interactive_input]

          if validate
            q.validate = validate
            q.responses[:not_valid] = ->(_x) { "\nERROR: #{last_validation_error}" }
            q.responses[:ask_on_error] = :question
          end
        end
      end

      # Prompt for an array of values using highline 'ask' with 'gather'
      # and possibly readline auto-completion from an array
      #
      # @param question [String] The question to ask
      # @param q_desc [String] A longer description of what we're asking for
      # @param convert [Lambda] The lambda for converting the validated value
      # @param validate [Lambda] The lambda for validating the answer before conversion
      # @param deets [Hash] The option-details for the value for which we are prompting
      #
      # @return [Array] The validated and converted values given by the user.
      ###############################
      def prompt_for_multi_values_with_highline(question:, q_desc:, deets:, convert: nil, validate: nil)
        use_readline, convert, validate = setup_for_readline_in_highline(deets, convert, validate)

        highline_cli.say q_desc

        chosen_values = highline_cli.ask(question, convert) do |q|
          if use_readline
            q.readline = true
            q.responses[:no_completion] = "Unknown Choice.#{HIGHLINE_READLINE_GATHER_ERR_INSTRUCTIONS}"
            q.responses[:ambiguous_completion] = "Ambiguous Choice.#{HIGHLINE_READLINE_GATHER_ERR_INSTRUCTIONS}"
          end
          if validate
            q.validate = validate
            q.responses[:not_valid] = ->(_x) { "\nERROR: #{last_validation_error}" }
            q.responses[:ask_on_error] = :question
          end
          q.gather = Xolo::X
        end

        # don't return an empty array if none was chosen, but
        # return 'none' so that the whole value is cleared.
        chosen_values = Xolo::NONE if chosen_values.include? Xolo::NONE
        chosen_values
      end

      # Prompt for a single multiline value via an editor, like vim.
      # This always returns a string.
      # We handle validation ourselves, since we can't use highline.ask
      #
      # @param question [String] The question to ask
      # @param q_desc [String] A longer description of what we're asking for
      # @param current_value [String] The string to start editing.
      # @param validate [Lambda] The lambda for validating the answer before conversion
      # @return [String] the edited value.
      ##############################
      def prompt_via_multiline_editor(question:, q_desc:, current_value: Xolo::BLANK, validate: nil)
        highline_cli.say "#{question}\n#{q_desc}"

        new_val = nil
        validated_new_val = nil
        editor = multiline_editor_to_use
        return if editor == Xolo::CANCEL

        until validated_new_val
          new_val = edited_multiline_value editor, q_desc, current_value
          if validate
            if validate.call new_val
              validated_new_val = last_converted_value
            else
              again = highline_cli.ask("\n#{last_validation_error}\nType a return to edit again, '#{Xolo::X}' to exit")
              break if again == Xolo::X
            end
          else
            validated_new_val = new_val
          end
        end

        validated_new_val || current_value
      end

      # Highline's ability to do autocompletion for local file selection is limited at best
      # (it only will autocomplete within a single directory, defaulting to the one
      # containing the executable)
      #
      # So if we want a shell-style autocompletion for selecting one or more files
      # then we'll use readline directly, where its pretty simple to do.
      #
      # @param question [String] The question to ask
      # @param q_desc [String] A longer description of what we're asking for
      # @param deets [Hash] The option-details for the value for which we are prompting
      # @param validate [Lambda] The lambda for validating the answer before conversion
      #
      # @return [Object] The validated and converted value given by the user.
      #######################
      def prompt_for_local_files_via_readline(question:, q_desc:, deets:, validate: nil)
        prompt = setup_for_readline_local_files(deets)

        highline_cli.say "#{q_desc}\n#{question}"

        validated_new_val = deets[:multi] ? [] : nil
        all_done = false
        until all_done
          latest_input = Readline.readline(prompt, true)
          break if latest_input == Xolo::X
          return Xolo::NONE if !deets[:required] && (latest_input == Xolo::NONE)

          if validate
            if validate.call latest_input
              latest_input = last_converted_value
            else
              highline_cli.say "#{last_validation_error}\nType 'x' to exit"
              next
            end
          end
          # if we are here, the latest_input is valid

          # We only validate individual items, but the validation
          # method might return an array (which it does for CLI option validation
          # for options that are stored in arrays - it validates them  all at once)
          # so deal with that here or we'll get nested arrays here.
          latest_input = latest_input.first if latest_input.is_a?(Array)

          if deets[:multi]
            validated_new_val << latest_input
          else
            validated_new_val = latest_input
            all_done = true
          end

        end # until all_done

        validated_new_val
      end

      # should we use readline, and if so
      # should we use an array of values or not?
      #
      # @param convert [Lambda] The lambda for converting the validated value
      # @param validate [Lambda] The lambda for validating the answer before conversion
      # @param deets [Hash] The option-details for the value for which we are prompting
      #
      # @return [Array] Three items:
      #   - if we should use readline (boolean)
      #   - the new 'convert' value - either the original passed to us or an array of possible values
      #   - the new 'validate' value - either the original passed to us or nil if using an array of values
      ############################
      def setup_for_readline_in_highline(deets, convert, validate)
        # if deets[:readline] is a symbol, its an xadm method that returns an array
        # of the possible values for readline completion and validation;
        # only things in the array are allowed, so no need for other validation or conversion
        # We add 'x' and 'none' to the list so they will be accepted for exiting and
        # clearing.
        #
        # if its just truthy then we use readline without a pre-set list of values
        # (e.g. paths, which might not exist locally) and may have a separate validate
        # and convert lambdas
        use_readline =
          if deets[:readline]
            if deets[:readline].is_a? Symbol
              convert = send deets[:readline]
              convert << Xolo::NONE unless deets[:required]
              convert << Xolo::X
              validate = nil
            end
            true
          else
            false
          end

        if use_readline
          # Case Insensitivity, aka deets[:readline_casefold]
          #
          # If deets[:readline_casefold] is explicitly true or false, we honor that.
          #
          # Otherwise, when we have an array of possible values, we make readline case insensitive.
          # and without such array, we make it sensitive (e.g. when selecting existing file paths)
          #
          # Setting this ENV is how we use our monkey patch to make this work
          ENV['XADM_HIGHLINE_READLINE_CASE_INSENSITIVE'] =
            case deets[:readline_casefold]
            when true
              Xolo::X
            when false
              nil
            else
              convert.is_a?(Array) ? Xolo::X : nil
            end

          # Setting this ENV is how we use our monkey patch to make this work
          prompt = deets[:readline_prompt] || deets[:multi_prompt] || deets[:label] || DEFAULT_HIGHLINE_READLINE_PROMPT
          ENV['XADM_HIGHLINE_READLINE_PROMPT'] = "#{prompt}: "
        end # if use_readline

        [use_readline, convert, validate]
      end

      # set up readline for local file autocomplete
      # return the prompt we'll be using with readline
      #
      # @param deets [Hash] The option-details for the value for which we are prompting
      #
      # @return [String] the prompt to use with readline
      #######################
      def setup_for_readline_local_files(deets)
        Readline.completion_append_character = nil
        Readline.basic_word_break_characters = "\n"
        Readline.completion_proc = proc do |str|
          str = Pathname.new(str).expand_path
          str = str.directory? ? "#{str}/" : str.to_s
          Dir[str + '*'].grep(/^#{Regexp.escape(str)}/)
        end
        prompt = deets[:readline_prompt] || deets[:label] || DEFAULT_HIGHLINE_READLINE_PROMPT
        "#{prompt}: "
      end

      # The 'default' value for the highline question
      # when prompting for a value
      # TODO: POSSIBLY NOT NEEDED. See commented-out call above
      ##############################
      def default_for_value(key, deets, curr_val)
        # default is the current value, or the
        # defined value if no current.
        default = walkthru_cmd_opts[key] || curr_val || deets[:default]
        default = default.join(Xolo::COMMA_JOIN) if default.is_a? Array
        default
      end

      # The multi-lines of text describing the value above the prompt
      # @param deets [Hash] The option-details for the value for which we are prompting
      # @return [String] the text to display
      ##############################
      def question_desc(deets)
        q_desc = +"============= #{deets[:label]} =============\n"
        q_desc << deets[:desc]

        if deets[:multiline]
          # nada, will be shown in the editor
        elsif deets[:multi]
          q_desc << "\nEnter one value per line."
          q_desc << "\nUse tab for auto-completion, tab twice to see available choices" if deets[:readline]
          q_desc << "\nType '#{Xolo::X}' on a line by itself to exit." if deets[:validate]

        else
          q_desc << "\nType a return to keep the current value."
        end

        q_desc
      end

      # The line of text prompting for a value.
      # End with a space to keep prompt on same line
      #
      # @param deets [Hash] The option-details for the value for which we are prompting
      # @return [String] the one-line prompt to display
      ##############################
      def question_for_value(deets)
        question = +"Enter #{deets[:label]}"

        if deets[:type] == :boolean
          question << ', (y/n)'
        elsif !deets[:required]
          question << ", use '#{Xolo::NONE}' to unset"
        end
        question << ': ' unless deets[:readline]
        question
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
      def validation_lambda(key, deets)
        val_meth = validation_method(key, deets)
        return unless val_meth

        # lambda to validate the value given.
        # must return boolean for Highline to deal with it.
        lambda do |ans|
          # to start, the converted value is just the given value.
          #
          # Use self here, otherwise the lambda sees 'last_converted_value ='
          # as a local variable assignment, not a setter method call
          self.last_converted_value = ans

          # default to the pre-written error message
          self.last_validation_error = deets[:invalid_msg]

          # if entering multi-values, a 'x' is how we get out of
          # the loop
          return true if deets[:multi] && ans == Xolo::X

          # but for anything not multi, an empty response
          # means user just hit return, nothing to validate,
          # no changes to make
          return true if ans.pix_blank?

          # If this value isn't required, accept 'none'
          # which clears the value
          return true if !deets[:required] && (ans == Xolo::NONE)

          # otherwise 'none' becomes nil and will be validated
          # and will fail if a value is required
          ans_to_validate = ans == Xolo::NONE ? nil : ans

          # validate using the val_meth,
          # saving the validated/converted value for use in the
          # convert method.
          self.last_converted_value = send(val_meth, ans_to_validate)
          true

        # if validation fails, set the last_validation_error
        # so we can display it and ask again
        rescue Xolo::InvalidDataError => e
          self.last_validation_error = e.to_s
          false
        end # lambda
      end

      # getter/setter for the value converted by the last validation
      # method call - we do this so the same value is available in the
      #  convert and validate lambdas
      #
      # @return [Object]
      ##############################
      attr_accessor :last_converted_value

      # getter/setter for any validation error message when
      # a validation fails.
      # @return [String]
      ##############################
      attr_accessor :last_validation_error

      # The method used to validate and convert a value
      # @param deets [Hash] The option-details for the value for which we are prompting
      # @param key [Symbol] One of the keys of the opts hash for the current command;
      #   the value for which we are prompting
      # @return [String, Symbol, nil] The method which will validate the value for the key
      ##############################
      def validation_method(key, deets)
        case deets[:validate]
        when TrueClass then "validate_#{key}"
        when Symbol then deets[:validate]
        end
      end

      # @return [Array<String>] The names of any required opts that have no current value.
      #   Displayed at the bottom of the walkthru menu.
      ##################################
      def missing_values
        missing_values = []
        required_values.each do |key, deets|
          next if walkthru_cmd_opts[key]

          missing_values << deets[:label]
        end
        missing_values
      end

      # Prompt for an editor to use from those in MULTILINE_EDITORS
      # @return [String] the path to an editor to use for multiline values.
      ##################
      def multiline_editor_to_use
        return config.editor if config.editor

        highline_cli.choose do |menu|
          menu.select_by = :index
          menu.prompt = 'Choose an editor:'
          MULTILINE_EDITORS.each do |name, cmd|
            menu.choice(cmd, nil, name)
          end # MULTILINE_EDITORS.each
          menu.choice(Xolo::CANCEL)
        end # @cli.choose
      end # def

      # Save some text in a temp file, edit it with the desired
      # multiline editor, save it then return the edited value.
      #
      # @param editor [String, Pathname] The path to the editor to use
      # @param text_to_edit [String] The text to edit
      #
      # @return [String] the edited text.
      ##################
      def edited_multiline_value(editor, desc, text_to_edit)
        f = Pathname.new(Tempfile.new('highline-test'))
        editor_content = "#{desc.chomp}\n#{MULTILINE_HEADER_SEPARATOR}\n#{text_to_edit}"
        f.pix_save editor_content
        system "#{editor} #{f}"
        f.read.split(MULTILINE_HEADER_SEPARATOR).last
      end

    end # module Interactive

  end # module Admin

end # module Xolo
