# Copyright 2025 Pixar
#
#    Licensed under the terms set forth in the LICENSE.txt file available at
#    at the root of this project.
#

proj_name = 'xolo-server'
lib_dir = 'xolo'

require "./lib/#{lib_dir}/core/version"

Gem::Specification.new do |s|
  # General

  s.name        = proj_name
  s.version     = Xolo::Core::Version::VERSION
  s.authors     = ['Chris Lasell']
  s.email       = 'xolo@pixar.com'
  s.homepage    = 'http://pixaranimationstudios.github.io/xolo/'
  s.date        = Time.now.strftime('%Y-%m-%d')

  s.license     = 'LicenseRef-LICENSE.txt'

  s.summary     = 'Automation and Standardization for Jamf Pro Patch Management'
  s.description = <<~EODDESC
    == Xolo
    Xolo (sorta pronounced 'show-low') is an HTTPS server and set of command-line tools for macOS that provide automatable access to the software deployment and patch management aspects of {Jamf Pro}[https://www.jamf.com/products/jamf-pro/] and the {Jamf Title Editor}[https://learn.jamf.com/en-US/bundle/title-editor/page/About_Title_Editor.html]. It enhances Jamf Pro's abilities in many ways:

      - Management of titles and versions/patches is scriptable and automatable, allowing developers and admins to integrate with CI/CD workflows.
      - Simplifies and standardizes the complex, multistep manual process of managing titles and patches using the Title Editor and Patch Management web interfaces.
      - Client installs can be performed by remotely via ssh and/or MDM
      - Automated pre-release piloting of new versions/patches
      - Titles can be expired (auto-uninstalled) after a period of disuse, reclaiming unused licenses.
      - And more!

    "Xolo" is the short name for the Mexican hairless dog breed {'xoloitzcuintle'}[https://en.wikipedia.org/wiki/Xoloitzcuintle] (show-low-itz-kwint-leh), as personified by Dante in the 2017 Pixar film _Coco_.

    The xolo-server gem packages the code needed to run `xoloserver`, the sinatra-based HTTPS server at the heart of Xolo.
  EODDESC

  s.required_ruby_version = '>= 2.6.3'

  # files
  s.files = Dir['lib/**/*.rb']

  # executables
  s.executables << 'xoloserver'

  # Core dependencies for both xadm and the server
  # TODO: test and try to use newer versions of all these dependencies.
  s.add_runtime_dependency 'faraday', '~> 2.8'
  s.add_runtime_dependency 'faraday-multipart', '~> 1.0'
  s.add_runtime_dependency 'pixar-ruby-extensions', '~> 1.11'

  # Server-specific dependencies
  s.add_runtime_dependency 'concurrent-ruby', '~> 1.1'
  s.add_runtime_dependency 'ruby-jss', '~> 4.2'
  s.add_runtime_dependency 'sinatra', '~> 3.2'
  s.add_runtime_dependency 'sinatra-contrib', '~> 3.2'
  s.add_runtime_dependency 'thin', '~> 1.8'
  s.add_runtime_dependency 'windoo', '~> 1.0'

  # Rdoc
  s.extra_rdoc_files = ['README.md', 'LICENSE.txt']
  s.rdoc_options << '--title' << 'Xolo-Server' << '--line-numbers' << '--main' << 'README.md'
end
