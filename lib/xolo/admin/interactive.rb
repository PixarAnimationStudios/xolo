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

      def cli
        @cli ||= Highline.new
      end

      #### prompt for and set a value
      def prompt_for_value(opts, key)
        deets = opts[key]

        question = +<<~ENDQ
          #{deets[:label]}
          #{deets[:desc]}
          Enter #{deets[:label]}:
        ENDQ
        question = question.chomp + ' '

        default = instance_variable_get("@#{key}")
        default ||= deets[:default]

        validate =
          case deets[:validate]
          when Regexp
            deets[:validate]
          when TrueClass
            ->(ans) { Xolo::Admin::Validate.send key, ans }
          when Symbol
            ->(ans) { Xolo::Admin::Validate.send deets[:validate], ans }
          end

        answer = cli.ask(question) do |q|
          q.default = default if default
          if validate
            q.validate = validate
            q.responses[:not_valid] = "ERROR: #{deets[:invalid_msg]}\n\n"
          end
          q.responses[:ask_on_error] = :question
        end
        instance_variable_set "@new_#{key}", answer
      end

    end # module Interactive

  end # module Admin

end # module Xolo
