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
        @cli ||= Highline.new
      end

      ####
      def self.menu_item_text(lbl, old: nil, new: nil)
        txt = +"#{lbl}: #{old}".strip
        return txt unless new

        txt << " => #{new}"
      end

      #### prompt for and return a value
      def self.prompt_for_value(_opts, key, deets)
        question = +<<~ENDQ
          #{deets[:label]}
          #{deets[:desc]}
          Enter #{deets[:label]}:
        ENDQ
        question = question.chomp + ' '

        # default is the current value, or the
        # defined value if no current.
        default = instance_variable_get("@#{key}")
        default ||= deets[:default]

        validate =
          case deets[:validate]
          when TrueClass
            ->(ans) { Xolo::Admin::Validate.send key, ans }
          when Symbol
            ->(ans) { Xolo::Admin::Validate.send deets[:validate], ans }
          end

        cli.ask(question) do |q|
          q.default = default if default
          if validate
            q.validate = validate
            q.responses[:not_valid] = "ERROR: #{deets[:invalid_msg]}\n\n"
          end
          q.responses[:ask_on_error] = :question
        end
      end

      # @param title [Xolo::Admin::Title]
      ######
      def self.display_title_menu_header(_title)
        system 'clear' or system 'cls'
        puts <<~ENDPUTS
          ------------------------------------
          Editing xolo title '#{title.title_id}'
          ------------------------------------
          Current Settings => New Settings
        ENDPUTS
      end

      # @param title [Xolo::Admin::Title]
      ####
      def self.display_title_menu(_title)
        done_with_title_menu = false

        until done_with_title_menu
          # clearn the screen and show the menu header
          display_title_menu_header

          # Generate the menu items
          cli.choose do |menu|
            # The menu items for setting values
            Xolo::Admin::Options::TITLE_OPTIONS.each do |key, deets|
              next if deets[:walkthru] == false

              oldv, newv = title.old_and_new(key)
              menu_item = menu_item_text(deets[:label], old: oldv, new: newv)

              menu.choice(menu_item) { prompt_for_value key, deets }
            end

            # only show 'done' when none are still needed,
            # and adjust the main menu prompt appropriately
            still_needed = missing_title_values(title)
            if still_needed.empty?
              prompt = 'Your Choice: '
              menu.choice('Done') { @done_with_title_menu = true }
            else
              prompt = "Missing Required Values: #{still_needed.join ', '}\nYour Choice: "
            end

            # always show 'Cancel' at the end
            menu.choice('Cancel') do
              @done_with_title_menu = true
              @cancelled = true
            end

            # and show the prompt we calculated above.
            menu.prompt = prompt
          end
        end # until
      end # def self.display_title_menu(_title)

      # @param title [Xolo::Admin::Title]
      ####
      ######
      def self.missing_title_values(title)
        missing_values = []
        Xolo::Admin::Options.required_title_values.each do |key, deets|
          next if title.send("@#{key}") || title.send("@new_#{key}")

          missing_values << deets[:label]
        end
        missing_values
      end

    end # module Interactive

  end # module Admin

end # module Xolo
