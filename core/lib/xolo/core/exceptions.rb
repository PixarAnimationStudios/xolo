# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#
#

module Xolo

  module Core

    module Exceptions

      # General errors

      class MissingDataError < RuntimeError; end

      class InvalidDataError < RuntimeError; end

      class NoSuchItemError < RuntimeError; end

      class UnsupportedError < RuntimeError; end

      class KeychainError < RuntimeError; end

      class ActionRequiredError < RuntimeError; end

      # Connections & Access

      class ConnectionError < RuntimeError; end

      class NotConnectedError < ConnectionError; end

      class TimeoutError < ConnectionError; end

      class AuthenticationError < ConnectionError; end

      class PermissionError < ConnectionError; end

      class InvalidTokenError < ConnectionError; end

      class ServerError < ConnectionError; end

      # Parsing errors

      class DisallowedYAMLDumpClass; end

    end # module Exceptions

  end # module Core

end # module Xolo
