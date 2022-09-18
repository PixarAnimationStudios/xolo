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

module Xolo

  module Server

    module TitleEditor

      class SoftwareTitle < Xolo::Core::BaseClasses::SoftwareTitle

        # Mixins
        ######################

        include Xolo::Core::Mixins::APICollection

        # Constants
        ######################

        LOCAL_TITLE_EDITOR_SOURCE_NAME = 'Local'
        LOCAL_TITLE_EDITOR_SOURCE_ID = 0

        RSRC_PATH = 'softwaretitles'

        # Public Class Methods
        ######################

        # Software Titles are the only collection resource that
        # has an endpoint that returns summary list.
        #
        # All others, patches, components, ext attrs, etc...
        # can only be individually accessed using their
        # primary identifier, so the .all and .valid_id methods
        # are not applicable to them.
        #
        # .all returns summmary Hashes for all Software Titles
        # in the Title Editor
        # the Hash keys are:
        #
        # :softwareTitleId=>1,
        # :enabled=>false,
        # :name=>"Test",
        # :publisher=>"Some Company",
        # :appName=>nil,
        # :bundleId=>nil,
        # :lastModified=>"2022-09-10T22:06:39Z",
        # :currentVersion=>"5.0.1",
        # :requirements=>3,
        # :patches=>0,  # Number of enabled patches, not existing patches.
        # :id=>"com.somecompany.test",
        # :sourceId=>0,
        # :source=>"Local"
        #
        # @return [Array<Hash>]
        ####
        def self.all
          Xolo::Server::TitleEditor.cnx.get(self::RSRC_PATH)
        end

        # @return [Xolo::Server::TitleEditor::SoftwareTitle]
        ####
        def self.fetch(ident = nil, **key_and_ident)
          id =
            if ident
              valid_id ident
            else
              key, ident = key_and_ident.first

              # Dont call valid_id if we are fetching based on the primary_ident_key
              # just used the value provided. The API will complain if it
              # doesn't exist
              key == primary_ident_key ? ident : valid_id(ident, key: key)
            end

          raise Xolo::NoSuchItemError, "No #{self} found for identifier '#{ident}'" unless id

          new Xolo::Server::TitleEditor.cnx.get("#{self::RSRC_PATH}/#{id}")
        end

        # @param ident [Integer, String] the identifier value to search for
        # @param key [Symbol] if given, Only look for the value in this key.
        # @return [Integer, nil] given any identifier, return the matching primary id
        #   or nil if no match
        ####
        def self.valid_id(ident, key: nil)
          if key
            matched_summary = all.select { |summary| summary[key] == ident }.first
          else
            all.each do |summary|
              ident_keys.each do |key|
                if summary[key] == ident
                  matched_summary = summary
                  break 2
                end
              end
            end
          end
          matched_summary ? matched_summary[primary_ident_key] : nil
        end

        # Attributes
        ######################

        # Attributes not defined in the superclasses

        JSON_ATTRIBUTES = {

          # This value only appears in the .all summary hash, not in the
          # full instance init_data.
          #
          # _!attribute source
          # _return [String] The name of the Patch Source that hosts ultimately
          #   hosts this title definition. If hosted by our TitleEditor
          #   directly, this is LOCAL_TITLE_EDITOR_SOURCE_NAME
          # source: {
          #   class: :String
          # },

          # @!attribute sourceId
          # @return [Integer] The id of the Patch Source that hosts ultimately
          #   hosts this title definition. If hosted by our TitleEditor
          #   directly, this is LOCAL_TITLE_EDITOR_SOURCE_ID
          sourceId: {
            class: :Integer
          },

          # @!attribute requirements
          #   @return [Array<Xolo::Core::BaseClasses::Requirement>] The requirements - criteria that
          #     define which computers have the software installed.
          requirements: {
            class: Xolo::Server::TitleEditor::Requirement,
            multi: true
          },

          # @!attribute patches
          #   @return [Array<Xolo::Core::BaseClasses::Patch>] The patches available for this title
          patches: {
            class: Xolo::Server::TitleEditor::Patch,
            multi: true
          },

          # @!attribute extensionAttributes
          #   @return [Array<Xolo::Core::BaseClasses::ExtensionAttribute>] The Extension Attributes used by this title
          extensionAttributes: {
            class: Xolo::Server::TitleEditor::ExtensionAttribute,
            multi: true
          }
        }.freeze

        # Construcor
        ######################
        def initialize(json_data)
          super
          @requirements = requirements.map { |data| Xolo::Server::TitleEditor::Requirement.new data }
          @patches = patches.map { |data| Xolo::Server::TitleEditor::Patch.new data }
          @extensionAttributes = extensionAttributes.map { |data| Xolo::Server::TitleEditor::ExtensionAttribute.new data }
        end

      end # class SoftwareTitle

    end # Module TitleEditor

  end # Module Server

end # Module Xolo
