# Xolo - CLI and Automated Package and Patch Management for Jamf Pro

<img src="http://pixaranimationstudios.github.io/xolo-home/images/dante.png" alt="Dante the xolo dog from the film Coco" width="200" height="200">


[Source Code](https://github.com/PixarAnimationStudios/xolo) &nbsp;&nbsp;&nbsp;&nbsp;[Documentation](https://github.com/PixarAnimationStudios/xolo/wiki)


Xolo (sorta pronounced 'show-low') is an http server and set of command-line tools for macOS that provide automatable access to the package deployment and patch management aspects of [Jamf Pro](https://www.jamf.com/products/jamf-pro/) and the [Jamf Title Editor](https://learn.jamf.com/en-US/bundle/title-editor/page/About_Title_Editor.html). It enhances Jamf Pro's abilities in many ways:

- Management of titles and versions/patches is scriptable and automatable, allowing developers and admins to integrate with CI/CD workflows.
- Simplifies and standardizes the complex, multistep manual process of managing titles and patches using the Title Editor and Patch Management web interfaces.
- Client installs can be performed by remotely via ssh and/or MDM
- Automated pre-release piloting of new versions/patches
- Titles can be expired (auto-uninstalled) after a period of disuse, reclaiming unused licenses.
- And more!

Xolo is the successor to depot3/d3, which allowed Patch Management via Jamf Pro before Jamf's own Patch Management system existed. Now that Jamf's Patch Management is stable and mature, d3 was rewritten from the ground up as xolo to take advantage of it, retaining a few unique enhancements that d3 provided. 

Unlike d3, xolo is built around 'pure-Jamf' processes, and everything it does can be done manually in the Title Editor and Jamf Pro web interfaces. 

"Xolo" is the short name for the Mexican hairless dog breed ['xoloitzcuintle'](https://en.wikipedia.org/wiki/Xoloitzcuintle) (show-low-itz-kwint-leh), as personified by Dante in the 2017 Pixar film _Coco_.

Xolo is built with two of our other open-source projects:

- [ruby-jss](http://github.com/PixarAnimationStudios/ruby-jss), 
which provides a ruby SDK for interacting with the 
[REST APIs of Jamf Pro](https://developer.jamf.com/jamf-pro/reference/classic-api)

- [windoo](http://github.com/PixarAnimationStudios/windoo), providing a ruby SDK for interacting with the 
[REST API of the Title Editor](https://developer.jamf.com/jamf-pro/reference/gettokenclaims).

See the xolo-admin.gemspec and xolo-server.gemspec files for other open-source tools and libraries used by Xolo.

For detailed documentation about Xolo:<br/>
(yet to be written....)

- xoloserver, the https server that makes it all go
- xadm, the Xolo admin tool for managing titles and versions via option-based or interactive command-line
- xolo, the Xolo client tool for manually working with titles and versions on managed Macs   
