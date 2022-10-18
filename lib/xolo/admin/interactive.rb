# Copyright 2022 Pixar
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

      def self.cli
        @cli ||= HighLine.new
      end

      # Use an interactive walkthru session to populate
      # Xolo::Admin::Options.cmd_opts
      #
      def self.walkthru
        cmd = Xolo::Admin::Options.command

        return unless Xolo::Admin::Options.global_opts.walkthru
        # if the command doesn't take any options, there's nothing to walk through
        return if Xolo::Admin::Options::COMMANDS[cmd][:opts].empty?

        display_walkthru_menu cmd
      end

      # @param title [Xolo::Admin::Title]
      ####
      def self.display_walkthru_menu(cmd)
        done_with_menu = false

        until done_with_menu
          # clearn the screen and show the menu header
          display_walkthru_header

          # Generate the menu items
          cli.choose do |menu|
            menu.responses[:ambiguous_completion] = nil
            menu.responses[:no_completion] = 'Unknown Choice'

            # The menu items for setting values
            ####
            Xolo::Admin::Options::COMMANDS[cmd][:opts].each do |key, deets|
              curr_val = current_values[key]
              new_val = Xolo::Admin::Options.cmd_opts[key]
              menu_item = menu_item_text(deets[:label], old: curr_val, new: new_val)

              # first arg is the 'name' which is used for text-based menu choosing,
              # and we want number-based, so set it to nil.
              # Second arg is 'help' which is not used unless the menu is a 'shell'
              # menu
              # third arg is 'text' which is the text of the menu item, and if left
              # out, the 'name' is used.
              # HighLine should really use keyword args for these, and prob will
              # eventially.
              menu.choice(nil, nil, menu_item) { prompt_for_value key, deets, curr_val }
            end

            # only show 'done' when none are still needed,
            # and adjust the main menu prompt appropriately
            still_needed = missing_values
            if still_needed.empty?
              prompt = 'Your Choice: '
              menu.choice(nil, nil, 'Done') { done_with_menu = true }
            else
              prompt = "Missing Required Values: #{still_needed.join ', '}\nYour Choice: "
            end

            # always show 'Cancel' at the end
            menu.choice(nil, nil, "Cancel\n") do
              done_with_menu = true
              @cancelled = true
            end

            # and show the prompt we calculated above.
            menu.prompt = prompt
          end
        end # until
      end # def self.display_title_menu(_title)

      # The menu header
      def self.display_walkthru_header
        header_action = Xolo::Admin::CommandLine.add_command? ? 'Adding' : 'Editing'
        header_target = "Xolo title '#{Xolo::Admin::Options.cmd_args.title}'"
        if Xolo::Admin::CommandLine.version_command?
          header_target = "Version #{Xolo::Admin::Options.cmd_args.version} of #{header_target}"
        end
        header_text = "#{header_action} #{header_target}"
        header_sep_line = '-' * header_text.length

        system 'clear'
        puts <<~ENDPUTS
          #{header_sep_line}
          #{header_action} #{header_target}
          #{header_sep_line}
          Current Settings => New Settings

        ENDPUTS
      end

      # The current/default values of the thing we are adding or editing
      def self.current_values
        return @current_values if @current_values

        @current_values = OpenStruct.new
        Xolo::Admin::Options::COMMANDS[Xolo::Admin::Options.command][:opts].each do |opt, deets|
          @current_values[opt] = deets[:default]
        end

        @current_values
      end

      ####
      def self.menu_item_text(lbl, old: nil, new: nil)
        txt = +"#{lbl}: #{old}".strip
        return txt unless new

        txt << " => #{new}"
      end

      #### prompt for and return a value
      def self.prompt_for_value(key, deets, curr_val)
        question = +<<~ENDQ
          #{deets[:label]}
          #{deets[:desc]}
          Enter #{deets[:label]}:
        ENDQ
        question = question.chomp + ' '

        # default is the current value, or the
        # defined value if no current.
        default = curr_val || deets[:default]

        # validate =
        #   case deets[:validate]
        #   when TrueClass
        #     ->(ans) { Xolo::Core::Validate.send key, ans }
        #   when Symbol
        #     ->(ans) { Xolo::Core::Validate.send deets[:validate], ans }
        #   end

        ans = cli.ask(question) do |q|
          q.default = default if default
          q.gather if deets[:multi]

          # if validate
          #   q.validate = validate
          #   q.responses[:not_valid] = "ERROR: #{deets[:invalid_msg]}\n\n"
          # end

          q.responses[:ask_on_error] = :question
        end

        Xolo::Admin::Options.cmd_opts[key] = ans
      end

      # @param deets [Hash] The details of this option/attribute
      # @return [Lambda] converts the given answer from a string to the desired type
      # def self.answer_converter(deets)
      #   ->(ans) do |q|
      #     case deets[:type]
      #     when :boolean
      #       Xolo::Admin::Converters.boolean ans
      #     when :integer
      #     when :float
      #     when :date

      #     end
      #     q.gather if deets[:multi]
      #   end
      # end

      ####
      ######
      def self.missing_values
        missing_values = []
        Xolo::Admin::Options.required_values.each do |key, deets|
          next if Xolo::Admin::Options.cmd_opts[key]

          missing_values << deets[:label]
        end
        missing_values
      end

    end # module Interactive

  end # module Admin

end # module Xolo
