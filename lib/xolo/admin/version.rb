# Copyright 2024 Pixar
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

# main module
module Xolo

  module Admin

    # A title used by xadm.
    # This add cli and walkthru UI, as well as
    # an interface to the Xolo Server for Title
    # objects.
    class Version < Xolo::Core::BaseClasses::Version

      UPLOAD_PKG_ROUTE = '/upload/pkg'

      # Class Methods
      #############################

      # @return [Hash{Symbol: Hash}] The ATTRIBUTES that are available as CLI & walkthru options
      def self.cli_opts
        @cli_opts ||= ATTRIBUTES.select { |_k, v| v[:cli] }
      end

      # Upload a .pkg (or zipped bundle pkg) for this version
      #
      # @param local_file [Pathname] The path to the file to be uploaded
      #
      # @return [Faraday::Response] The server response
      ##################################
      def upload_pkg
        return if pkg.pix_blank?
        return if pkg == Xolo::ITEM_UPLOADED

        route = "#{UPLOAD_PKG_ROUTE}/#{title}/#{version}"

        upfile = Faraday::UploadIO.new(
          pkg.to_s,
          'application/octet-stream',
          pkg.basename.to_s
        )

        content = { file: upfile }
        upload_cnx.post(route) { |req| req.body = content }
      end

    end # class Title

  end # module Admin

end # module Xolo
