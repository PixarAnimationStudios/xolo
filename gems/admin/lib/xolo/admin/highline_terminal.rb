# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
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
# and sets the prompt when calling Readline.readline
#
# TODO: Do this 'smartly' as with the monkeypatches in pixar-ruby-extensions
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
