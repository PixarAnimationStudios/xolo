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


#
module D3
  module Admin
    module Edit
      extend self

      # These are all the options that can be edited for an existing d3 package.
      # This also defines the order they're presented when editing via walkthru.
      #
      # This is defined as an array, separate from the keys of PKG_ATTRIBUTE_CONFIG
      #
      EDITING_OPTIONS = %w{
        version
        revision
        package_name
        filename
        category
        oses
        cpu_type
        reboot
        removable
        remove_first
        prohibiting_processes
        auto_groups
        excluded_groups
        pre_install
        post_install
        pre_remove
        post_remove
        expiration
        expiration_bundle_ids
        description
      }.map{|i| i.to_sym}

      # This is how nils and empty strings are displayed to the user
      NONE = "none"

      # Continuously loop through displaying the editing menu, and getting
      # new values, until the user types 'x'.
      #
      # @param pkg[D3::Package] the package being edited
      #
      # @return [Hash] A hash of changes to make to the pkg. Keys are the option
      #   symbols from EDITING_OPTIONS, values are new values
      #
      def loop_thru_editing_walkthru (pkg)

        editing_walkthru_state = initial_editing_walkthru_state(pkg)

        walkthru_menu_header = <<-ENDMENU
------------------------------------
Editing #{pkg.status} d3 package '#{pkg.patch}'
JSS Package id: #{pkg.id}
JSS Package name: #{pkg.package_name}
Installer filename: #{pkg.filename}
------------------------------------
Current Settings => New Settings
        ENDMENU

        choice = nil

        # loop until the user types an x
        while choice != "x"

          choice = D3::Admin::Interactive.get_menu_choice( walkthru_menu_header, walkthru_menu_lines(editing_walkthru_state) )

          break if choice == 'x'

          # the number they chose becomes an option key like :reboot
          chosen_opt = EDITING_OPTIONS[choice]

          # Here's the definition of the option from the OPTIONS hash
          opt_def = D3::Admin::OPTIONS[chosen_opt]

          # Here the value we're actually editing
          orig_opt_value = editing_walkthru_state[chosen_opt][:original_value]
          orig_opt_value ||= opt_def[:default]

          # prompt for a new value and put it in place
          editing_walkthru_state[chosen_opt][:new_value] = D3::Admin::Interactive.get_value( chosen_opt, orig_opt_value )


        end # while choice != x

        # extract just the changes to make
        changes_to_make = {}
        editing_walkthru_state.each do |opt, data|
          comparer = D3::Admin::OPTIONS[opt][:compare]
          if comparer
            next if (comparer.call data[:original_value], data[:new_value])
          else
            next if (data[:original_value].to_s == data[:new_value].to_s)
          end
          changes_to_make[opt] = data[:new_value]
        end # editing_walkthru_state.each do |opt, data|

        return changes_to_make

      end

      # A hash of hashes holding the state of the various options
      # of a pkg that can be edited during a walkthru.
      #
      # For each editable option it holds:
      # - the original value of the option from the pkg
      # - the textual-display version of that value, as created by the matching
      #   :display_conversion proc in D3::Admin::EDITING_OPTION_INFO
      # - The the new value when the user makes a change.
      #
      # @param pkg[D3::Package] the pkg being edited
      #
      # @return [Hash] the walkthru-editing values for the pkg
      #
      def initial_editing_walkthru_state (pkg)
        editing_walkthru_state = {}
        EDITING_OPTIONS.each do |o|
          original_value = pkg.send(o)
          converter = D3::Admin::OPTIONS[o][:display_conversion]
          editing_walkthru_state[o] = {
            :original_value => original_value,
            :original_value_display => converter ? converter.call(original_value) : original_value,
            :new_value => original_value
          } # end hash
          # set orig value displays that are empty to 'none'
          editing_walkthru_state[o][:original_value_display] = NONE if editing_walkthru_state[o][:original_value_display].to_s.empty?
        end # EDITING_OPTIONS.each do |o|
        return editing_walkthru_state
      end

      # Regenerate the walkthru menu lines
      #
      # @param editing_walkthru_state[Hash] the current state of the values being edited
      #
      # @return [Array<String>] the lines of the walkthru menu
      #
      def walkthru_menu_lines (editing_walkthru_state)

        display_lines = []
        EDITING_OPTIONS.each do |opt|
          # opt is the option symbol, like :reboot
          opt_def = D3::Admin::OPTIONS[opt]
          label = opt_def[:label]
          converter = opt_def[:display_conversion]

          # did the thing change?
          # compare the old and new either with .to_s and ==
          # or with the :compare proc defined in EDITING_OPTION_INFO
          if opt_def[:compare]
             option_didnt_change = (opt_def[:compare].call editing_walkthru_state[opt][:original_value], editing_walkthru_state[opt][:new_value])
          else
             option_didnt_change = (editing_walkthru_state[opt][:original_value].to_s ==  editing_walkthru_state[opt][:new_value].to_s)
          end

          # no change, so just display the orig value
          if option_didnt_change
            val_to_display = editing_walkthru_state[opt][:original_value_display]

          # But if the new val is different, convert it if needed, then show it as "orig => new"
          else
            new_value_display = converter ? converter.call(editing_walkthru_state[opt][:new_value]) : editing_walkthru_state[opt][:new_value]
            new_value_display = NONE if new_value_display.to_s.empty?
            val_to_display = "#{editing_walkthru_state[opt][:original_value_display]} => #{new_value_display}"
          end

          # make the line and add it to the array of lines
          display_lines << "#{label}: #{val_to_display}"
        end
        return display_lines
      end # def update_editing_display_lines(editing_options)

      # Validate the desired edits from the CLI options
      #
      # @param cli_options[OpenStruct] the options from the CLI
      #
      # @return [Hash] A hash of changes to make to the pkg. Keys are the option
      #   symbols from EDITING_OPTIONS, values are new values
      #
      def validate_cli_edits (cli_options)
        changes_to_make = {}
        EDITING_OPTIONS.each do |opt|
          if cli_options[opt]
            opt_check = D3::Admin::OPTIONS[opt][:validate]
            if opt_check
              changes_to_make[opt] = D3::Admin::Validate.send(opt_check, cli_options[opt])
            else
              changes_to_make[opt] = cli_options[opt]
            end
          end # if @options[opt]
        end #.each do |opt|
        changes_to_make
      end

      # Before making edits, check the possibly new patch in two ways:
      # 1) that it doesn't conflict with another patch in d3
      # 2) if the original package name contained the original patch
      #    and the patch has changed, change the package name to match.
      #
      # Raises an exception if there are patch conflicts
      #
      # @param pkg[D3::Package] the package we're editing
      #
      # @param changes_to_make[Hash] the changes we want to make
      #
      # @return [Hash] changes_to_make with a possibly new :name
      #
      def check_new_patch (pkg, changes_to_make)
        new_vers = changes_to_make[:version]
        new_rev = changes_to_make[:revision]
        if new_vers or new_rev
          potential_patch = "#{pkg.title}-#{new_vers ? new_vers : pkg.version}-#{new_rev ? new_rev : pkg.revision}"
          unless  pkg.patch == potential_patch
            # patch conflict?
            if  D3::Package.all_patchs.include? potential_patch
              raise JSS::AlreadyExistsError, "Can't change version or revision as requested: patch conflict with #{potential_patch}"
            end

            # name syncing?
            if pkg.name.include? pkg.patch
              changes_to_make[:package_name] = pkg.name.sub(pkg.patch, potential_patch ) unless changes_to_make[:package_name]
            end
          end # unless
        end # if new_vers or new_rev

        return changes_to_make
      end

      # Before making edits, confirm that the possibly new auto
      # or excluded groups don't overlap with each other.
      #
      # Raises an exception if there are overlaps
      #
      # @param pkg[D3::Package] the package we're editing
      #
      # @param changes_to_make[Hash] the changes we want to make
      #
      # @return [void]
      #
      def check_for_new_group_overlaps (pkg, changes_to_make)
        new_auto_gs = changes_to_make[:auto_groups]
        new_excl_gs = changes_to_make[:excluded_groups]
        bad_groups = []
        if new_excl_gs and new_auto_gs
          bad_groups = new_excl_gs & new_auto_gs
        elsif new_excl_gs
          bad_groups = new_excl_gs & pkg.auto_groups
        elsif new_auto_gs
          bad_groups = new_auto_gs & pkg.excluded_groups
        end
        raise "Auto and Excluded groups can't overlap!" unless bad_groups.empty?
        true
      end

      # Make the changes that have been requested with an edit
      #
      # @param pkg[D3::Package] the package we're editing
      #
      # @param changes_to_make[Hash] the changes we want to make
      #
      # @return [void]
      #
      def process_edits (pkg, changes_to_make)
        changes_to_make.each do |opt, new_val|
          setter = (opt.to_s + "=").to_sym
          pkg.send setter, new_val
        end
        pkg.save
        pkg.update_master_filename D3::Admin::Auth.rw_credentials(:dist)[:password] if changes_to_make[:filename]
      end

    end # module edit
  end # module Admin
end # module D3
