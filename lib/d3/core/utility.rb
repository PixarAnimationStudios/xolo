# Copyright 2018 Pixar
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

# the main modile
module D3

  # This file defines useful, general-use methods
  # for d3
  ################################################

  # Take in a multiline string and remove whitespace as if it was a
  # Ruby 2.3 'squiggly heredoc' e.g.:
  #
  # The indentation of the least-indented line will be removed
  # from each line of the content.
  #
  # This allows us to get the same results in earlier rubies.
  #
  # @param text[String] The text to squiggilize
  #
  # @return [String] the squiggilized text
  #
  def self.squiggilize_heredoc(text)
    leading_space_re = /^( +)/
    trim_length =
      text.lines.reject { |l| l.chomp.empty? }.map do |l|
        l =~ leading_space_re
        Regexp.last_match(1) ? Regexp.last_match(1).length : 0
      end.min
    trim_sub_re = /^ {#{trim_length}}/
    trimmed_text = ''
    text.each_line { |l| trimmed_text << l.sub(trim_sub_re, '') }
    trimmed_text
  end

  # Send a string to the terminal, possibly piping it through 'less'
  # if the number of lines is greater than the number of terminal lines
  # minus 3
  #
  # @param text[String] the text to send to the terminal
  #
  # @param show_help[Boolean] should the text have a line at the top
  #   showing basic 'less' key commands.
  #
  # @return [void]
  #
  def self.less_text(text, show_help = true)
    unless IO.console
      puts text
      return
    end

    height = IO.console.winsize.first

    if text.lines.count <= (height - 3)
      puts text
      return
    end

    if show_help
      help = "#------' ' next, 'b' prev, 'q' exit, 'h' help ------"
      text = "#{help}\n#{text}"
    end

    # point stdout through less, print, then restore stdout
    less = IO.popen('/usr/bin/less', 'w')
    begin
      less.puts text

    # this catches the quitting of 'less' before all the output
    # is displayed
    rescue Errno::EPIPE
      true
    ensure
      less.close
    end
  end

end # module d3
