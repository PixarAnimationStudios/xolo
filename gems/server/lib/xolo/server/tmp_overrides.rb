# Temp fixes for ruby-jss
###########################
module Jamf

  #########################
  module SelfServable

    # set ssvc notification settings in xml
    # FIX: its 'notification_enabled' NOT 'notifications_enabled'
    def add_self_service_notification_xml(ssvc)
      return unless @self_service_data_config[:notifications_supported]

      # oldstyle/broken, only sscv notifs
      if @self_service_data_config[:notifications_supported] == :ssvc_only
        ssvc.add_element('notification').text = self_service_notifications_enabled.to_s
        ssvc.add_element('notification_subject').text = self_service_notification_subject if self_service_notification_subject
        ssvc.add_element('notification_message').text = self_service_notification_message if self_service_notification_message
        return
      end

      # newstyle, 'notifications' subset
      notif = ssvc.add_element('notifications')
      # NEXT LINE IS THE FIX until pushed via ruby-jss, its 'notification_enabled' NOT 'notifications_enabled'
      notif.add_element('notification_enabled').text = self_service_notifications_enabled.to_s
      notif.add_element('notification_type').text = NOTIFICATION_TYPES[self_service_notification_type] if self_service_notification_type
      notif.add_element('notification_subject').text = self_service_notification_subject if self_service_notification_subject
      notif.add_element('notification_message').text = self_service_notification_message if self_service_notification_message

      return unless @self_service_data_config[:notification_reminders]

      reminds = notif.add_element('reminders')
      reminds.add_element('notification_reminders_enabled').text = self_service_reminders_enabled.to_s
      reminds.add_element('notification_reminder_frequency').text = self_service_reminder_frequency.to_s if self_service_reminder_frequency
    end

  end # module

end # module
