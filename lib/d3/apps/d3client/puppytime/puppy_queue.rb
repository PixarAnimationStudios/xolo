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
  module PuppyTime

      # PuppyQ - the current queue of pending puppy installs.
      #
      # This class only has one real value: A hash of
      # PendingPuppy objects, keyed by title.
      # But, PendingPuppies can be added and removed
      # and the queue can be read and written to disk
      #
      class PuppyQueue

        ############### Mixin Modules #################

        include Singleton

        ################ Class Constants #################

        QUEUE_FILE = D3::SUPPORT_DIR + "d3-pending-puppies.yaml"

        DFT_NOTIFICATION_FREQUENCY = 7

        ############### Class Methods #################


        ############### Attributes #################

        # the queue of PendingPuppy objects
        # A hash, keyed by title.
        attr_reader :q

        ############### Constructor #################

        # start by sett
        def initialize
          read_q
        end # init

        ############### Public Instance Methods #################

        # Read in the current puppy queue from disk
        # or set it to an empty hash if not there.
        #
        # @return [void]
        #
        def read_q
          if QUEUE_FILE.exist?
            @q = YAML.load(QUEUE_FILE.read)
            D3.log "Puppy queue loaded from disk", :debug
          else
            @q = {}
            D3.log "Created new empty puppy queue", :debug
          end
        end  # read_q

        # Save the current q out to disk
        #
        # @return [void]
        #
        def save_q
          D3.log "Saving puppy queue", :debug
          if @q.empty?
            D3.log "Puppy queue is empty, deleting from disk", :debug
            QUEUE_FILE.delete if QUEUE_FILE.exist?
          else
            QUEUE_FILE.jss_save YAML.dump(@q)
            D3.log "Puppy queue saved to disk", :debug
          end

        end # save_q

        # An array of titles for all pending puppies.
        #
        # @return [Array<String>] the titles of the pending puppies
        #
        def pups
          @q.keys
        end

        # Add a puppy to the queue
        #
        # @param puppy[D3::PendingPupppy] the puppy to add.
        #
        # @return [Boolean] True if the puppy was queued, false if already
        #   in the queue with a same or newer patch.
        #
        def + (puppy)

          raise TypeError, "You can only add PendingPuppy ojects to the PuppyQueue" unless puppy.class == D3::PuppyTime::PendingPuppy

          D3.log "Adding to puppy queue: #{puppy.patch}", :info

          # does this title already exist in the queue?
          # we can only have one patch per title in the queue at a time
          if pups.include? puppy.title
            in_q = @q[puppy.title]

            # if the pre-queued one is older, replace it with this one.
            if in_q.id < puppy.id
              D3.log "Replacing older puppy in queue: #{in_q.patch}", :warm
              self - puppy.title
            else
              if puppy.force
                D3.log "Puppy already in queue for '#{puppy.title}' is the same or newer (#{in_q.patch}), but force-adding", :warn
                self - puppy.title
              else
                D3.log "Puppy already in queue for '#{puppy.title}' is the same or newer (#{in_q.patch}), not adding", :warn
                return false
              end # if force
            end
          end # if @pups.include? puppy.title

          # note if we're starting with an empty queue
          started_empty = @q.empty?

          # Note when we're queueing
          puppy.queued_at = Time.now

          # add the new puppy
          @q[puppy.title] = puppy
          D3.log "Added puppy to queue: #{puppy.patch}", :info

          # save it
          save_q

          notify_puppies

          return true
        end # +

        # Remove a puppy from the queue
        #
        # @param puppy[String,D3::PendingPupppy] the title or D3::PendingPupppy
        #   for the puppy to be removed
        #
        # @return [Boolean] true if it was removed, false if it wasn't in the queue
        #
        def - (puppy)

          puppy = puppy.title unless puppy.is_a? String

          return false unless pups.include? puppy

          # remove it
          @q.delete puppy
          D3.log "Removed title #{puppy} from the puppy queue", :debug

          # save the queue
          save_q

          return true
        end # +

        # Should we run the puppytime notification policy?
        # returns the policy id or name, or false if we
        # shouldn't run.
        #
        # @return [String,Integer,false] the policy to run, if we should
        #
        def should_run_notification_policy
          # no puppies, no notify
          if @q.empty?
            D3.log "Not running puppytime notification policy: No puppies in queue", :debug
            return false
          end

          # no policy, no notify
          unless policy = D3::CONFIG.puppy_notification_policy
            D3.log "Not running puppytime notification policy: No policy in config", :debug
            return false
          end

          # no-notification option was given, no notify
          unless D3::Client.puppy_notification_ok_with_admin?
            D3.log "Not running puppytime notification policy: --no-puppy-notification was given", :debug
            return false
          end

          # how many days between notifications?
          frequency = D3::CONFIG.puppy_notification_frequency
          frequency ||= DFT_NOTIFICATION_FREQUENCY

          case frequency
          # zero means never notify
          when 0
            D3.log "Not running puppytime notification policy: Frequency set to Zero", :debug
            return false
          # -1 means always notify
          when -1
            D3.log "Frequency set to -1, always running puppytime notification policy", :debug
            return policy
          end

          unless last_notification = D3::CONFIG.puppy_last_notification
            # never been notified? always notify.
            D3.log "Puppytime notification policy never run, running now.", :debug
            return policy
          end # if last notiv

          # not long enough since last? no notify
          last_notification_days_ago = ((Time.now - last_notification) / 60 / 60 / 24).to_i
          unless last_notification_days_ago >= frequency
            D3.log "Not running puppytime notification policy: last notification #{last_notification_days_ago}/#{frequency} days ago", :debug
            return false
          end

          return policy
        end

        # Run the puppy notification policy, if there is one
        # and if its been long enough since the last run.
        #
        # @return [void]
        #
        def notify_puppies(verbose = false)

          return unless policy = should_run_notification_policy

          # put the queue patchs in the ENV
          puppies = @q.values.map{|p| p.patch}.join " "
          D3::Client.set_env :puppytime_notification, puppies

          D3.run_policy policy, :puppy_notification, verbose

          update_last_notification
          D3::Client.unset_env :puppytime_notification
        end

        # Update the last notification date in the config
        # to right-now.
        #
        # @return [void]
        #
        def update_last_notification
          D3.log "Updating last puppy notification time", :debug
          D3::CONFIG.puppy_last_notification = Time.now
          D3::CONFIG.save
        end # update last notification


        ############### Method Aliases #################

        alias queue q
        alias pending_puppies q
        alias puppies pups
        alias titles pups
        alias refresh read_q

      end # class PuppyQueue

  end # module puppytime

  # here's our one queue instance
  PUPPY_Q = D3::PuppyTime::PuppyQueue.instance

end #module d3
