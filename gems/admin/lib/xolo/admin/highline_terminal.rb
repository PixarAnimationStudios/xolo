# frozen_string_literal: true

class HighLine

  class Terminal

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
    #################################
    #
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

  end # class Terminal

end
