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

require 'xolo/puppytime/pending_puppy'
require 'xolo/puppytime/puppy_queue'

#
module Xolo

  # Constants and methods for PuppyTime, which installs the pkgs listed in the
  # PuppyQueue at logout.
  #
  module PuppyTime

    ############### Module Constants #################

    DFT_IMAGE_DIR = Xolo::SUPPORT_DIR + "puppytime"

    DFT_OPTOUT_IMAGE = DFT_IMAGE_DIR + "opt_out_image"

    DFT_NOTIFY_IMAGE = DFT_IMAGE_DIR + "notification_image"

    DFT_SLIDESHOW_DIR = DFT_IMAGE_DIR + "slideshow"

    DFT_OPTOUT_TEXT = "Software updates will start when you click OK,\nor when the timer runs out.\nClick cancel to postpone till next logout"

    DFT_OPTOUT_SECS = 30

    DFT_DISPLAY_SECS = 8

    DFT_TITLE = "PuppyTime!"

    DFT_IMG_SIZE = 250

    TEXT_POSITION = :center

    DFT_CAPTION = "The puppies are..."

    CAPTION_POSITION = :left

    COUNTDOWN_POSITION = :right

  end #module PuppyTime

end #module Xolo

