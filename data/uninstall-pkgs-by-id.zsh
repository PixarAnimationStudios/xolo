#!/bin/zsh

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

# Used by Xolo to uninstall packages based on one or more package-IDs as used by the
# 'pkgutil' command.
#
# This will get the list of files installed by each package-ID, and in a
# depth-first manner, delete them all. Directories will only be deleted if
# they are empty after deleting anything inside them what was installed by the same
# package. (hence the need for depth-first traversal)
#
# NOTE: This will not be useful if something was installed in a manner other than
# an installer.pkg (e.g. drag-installing an app) because there won't be
# a matching entry in the pkgutil database.
# It also won't help if the user has moved or renamed files after installation.

# DO NOT CHANGE THE VALUE OF IDS_TO_UNINSTALL
# This is a placeholder for the package IDs that Xolo will insert into the script
IDS_TO_UNINSTALL=(PKG_IDS_FROM_XOLO_GO_HERE)


# the current IDs known to pkgutil
IFS=$'\n' installed_pkgids=($(/usr/sbin/pkgutil --pkgs))

# iterate over our ids
for pkgid in $IDS_TO_UNINSTALL ; do

  # next unless this id is known
  if ! (( $installed_pkgids[(Ie)$pkgid] )) ; then
    echo "pkg ID $pkgid is not known"
    continue
  fi

  # the items to delete for a pkg ID
  IFS=$'\n' items_to_delete=($(/usr/sbin/pkgutil --files $pkgid ))

  # next if that failed for some reason
  if ! [[ $? = 0 ]] ; then
    echo "failed to get file list for $pkgid, skipping"
    continue
  fi

  # IMPORTANT - get the install volume and  install location to  prepend
  # to the pathnames
  inst_volume=$(/usr/sbin/pkgutil --pkg-info-plist $pkgid | /usr/bin/plutil -extract volume  raw -- -)
  echo "inst_volume is: '$inst_volume'"

  # if the inst_volume is set and it's last character is not a slash
  # we need to insert a slash after it
  [[ -n $inst_volume ]] && [[ "${inst_volume[-1]}" != '/' ]] && vol_slash='/'

  inst_location=$(/usr/sbin/pkgutil --pkg-info-plist $pkgid | /usr/bin/plutil -extract install-location raw -- -)
  echo "inst_location is: '$inst_location'"

  # if the location is also just /, then don't use it
  [[ "$inst_location" = '/' ]] && inst_location=''
  echo "inst_location is NOW: '$inst_location'"

  # if the inst_location is set and it's last character is not a slash
  # we need to insert a slash after it
  [[ -n $inst_location ]] && [[ "${inst_location[-1]}" != '/' ]] && loc_slash='/'


  echo "deleting files installed by $pkgid"
  echo '----------------'

  # we need iterate them in reverse them so that we delete things depth-first
  # which is what the (Oa) does
  for path in ${(Oa)items_to_delete}; do

    # echo "orig path is: '$path'"

    path_to_delete="${inst_volume}${vol_slash}${inst_location}${loc_slash}${path}"

    if [[ -f "$path_to_delete" ]] ; then
      echo  "$path_to_delete is a file - deleting it"
      /bin/rm -f "$path_to_delete"

    elif [[ -L "$path_to_delete" ]] ; then
      echo  "$path_to_delete is a symlink - deleting it"
      /bin/rm -f "$path_to_delete"

    elif [[ -d "$path_to_delete" ]] ; then
      echo "$path_to_delete is a directory..."

      if [[ $(/bin/ls -A "$path_to_delete" | /usr/bin/wc -l) -eq 0  ]] ; then
         echo "... and it's empty - deleting it"
         /bin/rm -f "$path_to_delete"
      else
         echo "... but its not empty - NOT deleting it"
      fi

    else
      echo "$path_to_delete doesn't exist'"
    fi

  done

  echo "done deleteing files from $pkgid"
  echo "------------------------------------"

done
