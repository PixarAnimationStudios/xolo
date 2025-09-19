# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

# frozen_string_literal: true

module Xolo

  module Server

    module Constants

      # when this module is included
      def self.included(includer)
        Xolo.verbose_include includer, self
      end

      # Constants
      #####################################

      EXECUTABLE_FILENAME = 'xoloserver'

      # Sinatra App Environments

      APP_ENV_DEV = 'development'
      APP_ENV_TEST = 'test'
      APP_ENV_PROD = 'production'

      # Sinatra App Settings

      SESSION_EXPIRE_AFTER = 3600 # seconds

      # Paths

      DATA_DIR = Pathname.new('/Library/Application Support/xoloserver')

      BACKUPS_DIR = DATA_DIR + 'backups'

      # streaming progress from the server.
      # When a line containing only this string shows up in a stream file
      # that means the stream is done, and no more lines will be sent.
      PROGRESS_COMPLETE = 'PROGRESS_COMPLETE'

      # The max time (in seconds) to wait for a the Jamf server to
      # see a change in the Title Editor, e.g.
      # a new version appearing or an EA needing acceptance.
      # Normally the Jamf server will check in with the Title Editor
      # every 5 minutes.
      MAX_JAMF_WAIT_FOR_TITLE_EDITOR = 3600

      # The max time (in seconds) to wait for a the Jamf server to
      # stop the pkg deletion thread pool. It will wait until the
      # queue is empty, or until this time has passed.
      # Each pkg deletion thread can take up to 5 minutes, and
      # there are 10 threads in the pool.
      MAX_JAMF_WAIT_FOR_PKG_DELETION = 3600

      # Jamf objects are named with this prefix followed by <title>-<version>
      # See also:  Xolo::Server::Version#jamf_obj_name_pfx
      # which holds the full prefix for that version, and is used as the
      # full object name if appropriate (e.g. Package objects)
      JAMF_OBJECT_NAME_PFX = 'xolo-'

    end # module Constants

  end #  Server

end # module
