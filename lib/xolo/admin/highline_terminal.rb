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

# MonkeyPatch HighLine::Terminal#readline_read so that Readline
# lines can be case-insensitive, and have a prompt.
#
# To use a prompt, put it in the environtment variable 'XADM_HIGHLINE_READLINE_PROMPT'
#
# To make the readline completion case-insensitive, set the environment
# variable XADM_HIGHLINE_READLINE_CASE_INSENSITIVE to anything.
#
# This really only modifies the Regexp used for the completion_proc to make it
# case insensitive if desired (adding an 'i' to the end)
# and sets the prompt when calling Readlin.readline
#
class HighLine

  class Terminal

    # Use readline to read one line
    # @param question [HighLine::Question] question from where to get
    #   autocomplete candidate strings
    #################################
    def readline_read(question)
      # prep auto-completion
      unless question.selection.empty?
        Readline.completion_proc = lambda do |str|
          regex = ENV['XADM_HIGHLINE_READLINE_CASE_INSENSITIVE'] ? /\A#{Regexp.escape(str)}/i : /\A#{Regexp.escape(str)}/
          question.selection.grep(regex)
        end
      end

      # work-around ugly readline() warnings
      old_verbose = $VERBOSE
      $VERBOSE    = nil

      raw_answer  = run_preserving_stty do
        Readline.readline(ENV['XADM_HIGHLINE_READLINE_PROMPT'].to_s, true)
      end

      $VERBOSE = old_verbose

      raw_answer
    end

    # Get one line from terminal using default #gets method.
    ##############################
    # def get_line_default(highline)
    #   raise EOFError, 'The input stream is exhausted.' if highline.track_eof? && highline.input.eof?

    #   highline.output.print "#{ENV['XADM_HIGHLINE_LINE_PROMPT']}" if ENV['XADM_HIGHLINE_LINE_PROMPT']

    #   highline.input.gets
    # end

  end # terminal

  # # Deals with the task of "asking" a question
  # class QuestionAsker

  #   alias ask_once_real ask_once

  #   # Gets just one answer, as opposed to #gather_answers
  #   #
  #   # @return [String] answer
  #   def ask_once
  #     @highline.output.print "#{ENV['XADM_HIGHLINE_LINE_PROMPT']}" if ENV['XADM_HIGHLINE_LINE_PROMPT']
  #     ask_once_real
  #   end

  # end # question asker

end
