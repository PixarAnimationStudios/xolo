module Xolo

  # An application that must be killed before a version can be
  # installed.
  class KillApp
    include Comparable

    DOT = '.'.freeze
    DOT_APP = '.app'.freeze

    # @return [String] used by jamf patch polcies and d3 to kill processes
    attr_reader :app_name

    # @return [String] used by jamf patch polcies and d3 to kill processes
    attr_reader :bundle_id

    def initialize(**args)
      @app_name = validate_app_name args[:app_name]
      @bundle_id = validate_bundle_id args[:bundle_id]
    end

    def validate_app_name(name)
      raise JSS::InvalidDataError, 'app_name must be a String ending in .app' unless name.is_a?(String) && name.end_with?(DOT_APP)
      name
    end

    def validate_bundle_id(bid)
      raise JSS::InvalidDataError, 'bundle_id must be a String with at least one dot' unless bid.is_a?(String) && bid.include?(DOT)
      bid
    end

    def show_d3_alert
      # TODO: move this to the version, so it does one
      # alert for all of its killapps
      # TODO: Use jamf helper, since Notification Ctr can't be forced
      # to show msgs as alerts not banners - but - try to respect
      # do not disturb? (available in Jamf::Client.do_not_disturb?)
      management_action(msg, title: nil, subtitle: nil, delay: 0, user: nil)
    end

    def id
      "#{bundle_id}-#{app_name}"
    end

    def <=>(other)
      id <=> other.id
    end

    def kill
      # TODO: this... nicely first with osascript quit?  Or just kill -9 ?
    end

    def pid
      pid = `/usr/bin/lsappinfo info #{@bundle_id} -only pid`.chomp.split('=').last
      pid ? pid.to_i : pid
    end

    # used in Title#to_json to pass between d3 server and clients
    def json_data
      { app_name: app_name, bundle_id: bundle_id }
    end

    # provided to the JSS from the d3 Patch Source
    def patch_source_json
      {
        bundleID: bundle_id,
        appName: app_name
      }.to_json
    end

  end # class KillApp

end # module Xolo
