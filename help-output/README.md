# Xolo Help Output

Eventually I'll write proper online documentation.

But in the  meantime, here's all the possible help output from `xadm` `xoloserver` and `xolo`

I'll try to keep these pages updated as the output itself is updated.

## xadm

This is the xolo admin tool, used for managing titles and versions via xolo. Folks who maintain packages in d3 using `d3admin` will be using xadm for manual and automated deployment of software in Xolo.

## xolo

This is the client-side tool for installing, uninstalling and related tasks on managed Macs. Unlike xadm and xoloserver, which are large complex tools written in ruby, xolo itself is a zsh script, basically a glorified wrapper around the `jamf policy` command.

## xoloserver

This is the https server that ties everything together, acting as the communicator between xadm, Jamf Pro, and the Title Editor, and maintaining some of its own info about titles and versions in xolo.

See the flowchart at (non-pixar-link TBD) https://wiki.pixar.com/pages/viewpage.action?pageId=567230127 for an overview.