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
module Xolo

  module Utility

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
    def less_text(text, show_help = true)
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

    # Very handy!
    # lifted from
    # http://stackoverflow.com/questions/4136248/how-to-generate-a-human-readable-time-range-using-ruby-on-rails
    #
    # Turns the integer 834756398 into the string "26 years 23 weeks 1 day 12 hours 46 minutes 38 seconds"
    #
    # @param secs [Integer] a number of seconds
    #
    # @return [String] a human-readable (English) version of that number of seconds.
    #
    def humanize_secs(secs)
      [[60, :second], [60, :minute], [24, :hour], [7, :day], [52.179, :week], [1_000_000_000, :year]].map do |count, name|
        next unless secs > 0

        secs, n = secs.divmod(count)
        n = n.to_i
        "#{n} #{n == 1 ? name : (name.to_s + 's')}"
      end.compact.reverse.join(' ')
    end

  end # module Utility
  
  extend Utility

end # module Xolo
