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
module Xolo
  module Admin

    # The Admin::Add modile contains constants and methods related to
    # adding packages to d3 via d3admin.
    #
    module Add
      extend self

      # These are the symbols representing all the possible commandline options
      # used for defining new packages.
      NEW_PKG_OPTIONS = %w{
          version
          revision
          package_name
          description
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
          source_path
        }.map{|i| i.to_sym}

      # If we need to build the pkg, these options are needed
      BUILD_OPTIONS = [:workspace, :package_build_type]

      # If we are building a .pkg these options are needed
      PKG_OPTIONS = [:pkg_identifier, :pkg_preserve_owners]

      # Continuously loop through displaying the add-package menu, and getting
      # new values, until the user types 'x'.
      #
      # @param options[OpenStruct] the starting values to offer the user
      #
      # @return [OpenStruct] the new_package_options with validated data
      #
      def loop_thru_add_walkthru (options)

        inherited_line = options.inherited_from ? "with values inherited from '#{options.inherited_from}'" : "with global default values"



        choice = nil

        # loop until the user types an x
        while choice != "x"
          walkthru_menu_header = <<-END_HEADER
------------------------------------
Adding pilot d3 package '#{options.patch or options.title}'
#{inherited_line}
------------------------------------
END_HEADER
          menu_options = NEW_PKG_OPTIONS
          if options.source_path and get_package_type_from_source(options.source_path) == :root_folder
            menu_options += BUILD_OPTIONS
            menu_options += PKG_OPTIONS if options.package_build_type == :pkg
          end

          choice = Xolo::Admin::Interactive.get_menu_choice( walkthru_menu_header, walkthru_menu_lines(menu_options, options) )

          if choice == 'x'
            (options, errors) = validate_all_new_package_options options
            if errors.empty?
              break # while
            else
              puts "***** ERRORS *****"
              puts errors.join "\n"
              puts "*****"
              puts "Type return to continue, ^c to exit"
              gets
              choice = 'not x'
            end # if errors empty
          else

            # the number they chose becomes an option key like :reboot
            chosen_opt = menu_options[choice]

            # Here the value we're actually editing
            current_opt_value = options[chosen_opt]


            # if we're editing version or revision, and the current pkg or filenames are
            # based on them then make a note to update the names  when we get the new values
            if chosen_opt == :title or chosen_opt == :version or chosen_opt == :revision
              update_patch = true
              update_pkg_name = options.package_name.start_with? options.patch
              update_filename = options.filename.start_with? options.patch
            else
              update_patch = false
              update_pkg_name = false
              update_filename = false
            end

            # if editing the source or the buildtype, we might have to update the
            # names as well
            if chosen_opt == :source_path or chosen_opt == :package_build_type
              update_pkg_name = options.package_name =~ /\.(m?pkg|dmg)$/
              update_filename = true
            end

            # prompt for a new value and put it in place
            options[chosen_opt] = Xolo::Admin::Interactive.get_value(chosen_opt, current_opt_value, nil)

            # if we changed the version, reset the revision to 1 and update values as needed
            if chosen_opt == :version and options[chosen_opt] != current_opt_value
              options[:revision] = 1
              update_patch = true
              update_pkg_name = options.package_name.start_with? options.patch
              update_filename = options.filename.start_with? options.patch
            end

            # if we edited the version or revision, we might need to update names and patch
            options.patch = "#{options.title}-#{options.version}-#{options.revision}" if update_patch
            options.package_name = "#{options.patch}.#{options.package_build_type}" if update_pkg_name
            options.filename = "#{options.patch}.#{options.package_build_type}" if update_filename

            # if we edited the source path, we might need to update the names and the pkg build type
            if chosen_opt == :source_path and options.source_path.extname =~  /\.(m?pkg|dmg)$/
              options.package_name.sub(/\.(m?pkg|dmg)$/, options.source_path.extname)
              options.filename.sub(/\.(m?pkg|dmg)$/, options.source_path.extname)
              options.package_build_type = options.source_path.extname == ".dmg" ? :dmg : :pkg
            end

            # ditto if we edited the package_build_type
            if chosen_opt == :package_build_type
              options.package_name.sub(/\.(m?pkg|dmg)$/, options.package_build_type.to_s)
              options.filename.sub(/\.(m?pkg|dmg)$/, options.package_build_type.to_s)
            end

          end #if choice == x
        end # while choice not x

        # return the options
        options

      end # loop_thru_add_walkthru

      # Regenerate the walkthru menu lines
      #
      # @param menu_options[Array<Symbol>] the option keys that will be in
      #  the menu
      #
      # @param current_options[OpenStruct] the current option values
      #
      # @return [Array<String>] the lines of the walkthru menu
      #
      def walkthru_menu_lines (menu_options, current_options)
        display_lines = []

        menu_options.each_index do |i|
          # the option symbol, like :reboot
          #opt = NEW_PKG_OPTIONS[i]
          opt = menu_options[i]
          opt_def = Xolo::Admin::OPTIONS[opt]
          label = opt_def[:label]
          value = current_options[opt]
          converter = opt_def[:display_conversion]
          value_display = converter ? converter.call(value) : value
          display_lines[i] = "#{label}: #{value_display}"
        end
        return display_lines
      end # def walkthru_menu_lines

      # Validate commandline options when adding a package without walkthru
      # using defaults as needed.
      # Some values will be prompted for if needed, since they
      # are required and can't use defaults.
      #
      # @param cli_options[OpenStruct] the values from the command line
      #
      # @param new_package_options[OpenStruct] the repository for the
      #   validated data
      #
      # @return [OpenStruct] the new_package_options with validated data
      #
      def add_pilot_cli (cli_options)
        (new_package_options, errors) = validate_all_new_package_options (cli_options)
        if errors.empty?
          return new_package_options
        else
          puts "***** ERRORS *****"
          puts errors.join "\n"
          puts "*****"
          raise ArgumentError, "Errors in commandline options, see above."
        end # if errors empty
      end #validate_cli_add_pilot

      # Validate all possible options for making a new pkg.
      #
      # This is used for both walkthru's and cli-specified options.
      # Even though the walkthru validates options as they are entered,
      # some need to be checked after all have been provided, e.g.
      # possibly overlapping groups, patch conflicts, etc.
      #
      # @param options_from_user[OpenStruct] the collection of all options to check as a group.
      #   either from a walkthru or the command line
      #
      # @return [Array<OpenStruct, Array>] An array with two items: the possibly-validated options
      #   and an array of error messages, which should be empty if all options are valid.
      #
      def validate_all_new_package_options (options_from_user)

        # what do we need to check
        opts_to_check = NEW_PKG_OPTIONS
        if options_from_user.source_path and get_package_type_from_source(options_from_user.source_path) == :root_folder
          opts_to_check += BUILD_OPTIONS
          opts_to_check += PKG_OPTIONS if options_from_user.package_build_type == :pkg
        end

        # gather the errors in here to be reported all at once
        errors = []

        # basic checks
        opts_to_check.each do |opt|
          puts "checking #{opt}: #{options_from_user[opt]}" if Xolo::Admin.debug
          if options_from_user[opt] == Xolo::Admin::DFT_REQUIRED
            errors << "Missing required value for #{Xolo::Admin::OPTIONS[opt][:label]}"
            next
          end

          (valid, validated) = Xolo::Admin::Validate.validate(options_from_user[opt], Xolo::Admin::OPTIONS[opt][:validate])
          if valid
            options_from_user[opt] = validated
          else
            errors << validated
          end
        end # opts_to_check.each

        # now check the patch
        new_patch = "#{options_from_user.title}-#{options_from_user.version}-#{options_from_user.revision}"
        if Xolo::Package::Validate.patch_exist? new_patch
          errors << "A package with patch '#{new_patch}' already exists in d3."
        else
          options_from_user.patch = new_patch
        end

        # group overlaps
        begin
           Xolo::Package::Validate.validate_non_overlapping_groups options_from_user[:auto_groups], options_from_user[:excluded_groups]
        rescue JSS::InvalidDataError
           errors << "Auto and Excluded group-lists can't contain groups in common."
        end

        # expiration path if expiration
        if options_from_user[:expiration] > 0
            errors << "expiration path cannot be empty if expiration is > 0 ." unless options_from_user[:expiration_bundle_ids]
        end
        return [options_from_user, errors]
      end # validate_all_new_package_options

      # Figure out the default values for all options for creating a new package
      #
      # @param title[String] the title for the new pkg
      #
      # @return [OpenStruct] an ostruct with the default values
      #
      def get_default_options(title, no_inherit)

        dft_opts = OpenStruct.new

        # first populate the opts from the defined defaults for anything that's still nil
        Xolo::Admin::OPTIONS.each {|opt, settings| dft_opts[opt] = settings[:default]}

        dft_opts.title = title

        # next we grab stuff from the most recent pkg with this baseneme
        # and apply anything there, if a title was given
        unless no_inherit
          if Xolo::Package.all_titles.include? title
            prev_pkg = Xolo::Package.most_recent_package_for(title)
            if prev_pkg
              dft_opts = self.default_options_from_package(prev_pkg, dft_opts)
              dft_opts.inherited_from = prev_pkg.patch
            end
          end
        end #  if title

        # patch if available
        if dft_opts.version and dft_opts.revision
          dft_opts.patch = "#{dft_opts.title}-#{dft_opts.version}-#{dft_opts.revision}"
        else
          dft_opts.patch = nil
        end

        # and if we have an patch, we have default pkg and file names
        if dft_opts.patch
          dft_opts.package_name = "#{dft_opts.patch}"
          dft_opts.filename = "#{dft_opts.patch}.#{dft_opts.package_build_type}"
        end

        # then: any values stored in the admin prefs are applied...
        # use the workspace from the prefs if it exists
        dft_opts.workspace = Xolo::Admin::Prefs.prefs[:workspace]
        dft_opts.workspace ||= Xolo::Admin::DFT_WORKSPACE


        # use the pkg_identifier_prefix from the prefs
        pfx = Xolo::Admin::Prefs.prefs[:apple_pkg_id_prefix]
        pfx ||= Xolo::Admin::DFT_PKG_ID_PREFIX
        dft_opts.pkg_identifier ||= "#{pfx}.#{title}".gsub(/\.+/, '.')

        # We now have our defaults for a new pkg
        dft_opts.signing_identity = Xolo::Admin::Prefs.prefs[:signing_identity] || nil
        dft_opts.signing_options = Xolo::Admin::Prefs.prefs[:signing_options] || nil

        dft_opts
      end # populate_default_options

      # Get default values from an existing d3 package, and use them to
      # override the defined defaults
      #
      # @param pkg[Xolo::Package] the package from which to extract the values
      #
      # @param dft_opts[OpenStruct] an Ostruct with the defined defaults already
      #   populated
      #
      # @return  [OpenStruct] an ostruct with the default values
      #
      def default_options_from_package(pkg, dft_opts = OpenStruct.new)

        # populate the opts from the pkg, if the pkg has a value
        Xolo::Admin::OPTIONS.keys.each do |opt|
          next unless pkg.respond_to?(opt)
          pkg_val = pkg.send(opt)
          next if pkg_val.nil?
          dft_opts[opt] = pkg_val
        end # do opt

        # bump the revision by 1
        dft_opts.revision += 1

        # never use the older package name or filename
        dft_opts.package_name = nil
        dft_opts.filename = nil

        # grab the first pkg-id if it exists
        # we might use it to if making a new pkg
        if pkg.apple_receipt_data and pkg.apple_receipt_data[0] and pkg.apple_receipt_data[0][:apple_pkg_id]
          dft_opts.pkg_identifier = pkg.apple_receipt_data[0][:apple_pkg_id]
        end

        dft_opts
      end # default_values_from_package(pkg)

      # Given a source_path, check if its a dmg, or .pkg
      # Assumes the source_path has been checked and
      # is valid.
      #
      # @param source_path[Pathname] the path to check
      #
      # @return [Symbol] :dmg, :pkg, or :root_folder
      #
      def get_package_type_from_source (source_path)
        if source_path.to_s.end_with? '.dmg'
          :dmg
        elsif source_path.to_s =~ /\.m?pkg$/
          :pkg
        else
          :root_folder
        end # if .source_path.to_s.end_with? '.dmg'
      end

      # Add the new pkg to d3
      #
      # @param new_package_options[OpenStruct] the verified options for the new package.
      #
      # @return [Integer] the JSS id of the new package
      #
      def add_new_package (new_package_options)

        # new_package_options should now have all the validated data we need to make a new pkg
        new_pilot = Xolo::Package.new(:id => :new,
          :title => new_package_options.title,
          :name => new_package_options.package_name,
          :version => new_package_options.version,
          :revision => new_package_options.revision,
          :filename => new_package_options.filename,
          :admin => ENV["USER"])

        Xolo::Admin::Add::NEW_PKG_OPTIONS.each do |opt|
          setter = "#{opt}=".to_sym
          new_pilot.send setter, new_package_options.send(opt) if new_pilot.respond_to? setter
        end

        # do we need to build the pkg?
        unless new_package_options.source_path.extname =~ /\.(m?pkg|dmg)$/
          if new_package_options.package_build_type == :pkg
            puts "Building .pkg..."
            new_pkg_path = JSS::Composer.mk_pkg(new_package_options.package_name,
              new_package_options.version,
              new_package_options.source_path,
              :pkg_id => new_package_options.pkg_identifier,
              :out_dir => new_package_options.workspace,
              :preserve_ownership => new_package_options.pkg_preserve_owners )

            new_package_options.source_path = new_pkg_path

          elsif new_package_options.package_build_type == :dmg
            puts "Building .dmg..."
            new_pkg_path = JSS::Composer.mk_dmg(new_package_options.package_name,
              new_package_options.source_path,
              new_package_options.workspace)

            new_package_options.source_path = new_pkg_path
          end # if new_package_options.package_build_type
        end # unless

        # save to d3
        puts "Saving new pilot #{new_package_options.patch} to the server..."

        new_pkg_id = new_pilot.save

        puts "Indexing..."
        # make the index - all d3 pkgs are indexed in the JSS
        new_pilot.mk_index :local_filepath => new_package_options.source_path

        # upload to dist point
        # if its a .pkg, the apple rcpt data is updated during the upload
        puts "Uploading to the Master Distribution Point..."
        new_pilot.upload_master_file new_package_options.source_path, Xolo::Admin::Auth.rw_credentials(:dist)[:password]

        return new_pkg_id

      end # add_new_package

    end # module Add
  end # module Admin
end # module Xolo
