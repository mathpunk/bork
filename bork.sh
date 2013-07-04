#!/bin/bash
brew () {
  local pkg=${1}
  local c=''
  if includes "$brews_have" "$pkg" ; then
    if includes "$brews_outdated" "$pkg" ; then
      c="brew upgrade $pkg"
    fi
  else
    c="brew install $@"
  fi
  if [ -n "$c" ] ; then bake "command $c" ; fi
}
brews_have=$(command brew list)
brews_outdated=$(command brew outdated | awk '{print $1}')

github () {
  repo=$1
  dir=$(get_directory $2)
  if [ ! -d $dir ]; then
    c="mkdir -p $dir"
    c="$c && git clone --bare https://github.com/$(echo $repo).git $dir"
  else
    c="cd $dir && git pull"
  fi
  if [ -n "$c" ] ; then
    bake "$c"
  fi
}


nodenv () {
  if ! includes "$(command nodenv versions --bare )" $1; then
    bake "command nodenv install $1"
  fi
}

osx_lookups=$(cat <<EOF
dialogs.expandAll: NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
dialogs.expandAll: NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

ui.fast: NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
ui.fast: NSGlobalDomain NSWindowResizeTime .001

showAllFiles: NSGlobalDomain AppleShowAllExtensions -bool true
finder.disableNetworkDS: com.apple.desktopservices DSDontWriteNetworkStores -bool true

dock.autohide: com.apple.dock autohide -bool true
dock.static: com.apple.dock static-only -bool true

timeMachine.off: com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
EOF)

osx () {
  directives=$(echo "$osx_lookups" | grep -e "$1:\s\+")
  echo "$directives" | while read directive; do
    domain=$(get_field "$directive" 2)
    key=$(get_field "$directive" 3)
    val_or_type=$(get_field "$directive" 4)

    if includes "$val_or_type" "^\-"; then
      type=$val_or_type
      val=$(get_field "$directive" 5)
    else
      type='-string'
      val=$val_or_type
    fi

    existing_val=$(defaults read "$domain" "$key")
    existing_type="$(get_field "$(defaults read-type "$domain" "$key")" 3)"

    type_matches=false
    val_matches=false

    if [[ "$existing_type" = "-$type" ]]; then
      type_matches=true
    elif [[ "$existing_type" = "boolean" ]] && [[ "$type" = "-bool" ]]; then
      type_matches=true
      if [[ $existing_val = 0 ]] && [[ $val = "false" ]]; then
        val_matches=true
      elif [[ $existing_val = 1 ]] && [[ $val = "true" ]]; then
        val_matches=true
      fi
    fi

    if [[ "$val" = "$existing_val" ]]; then
      val_matches=true
    fi

    if [[ $val_matches = false ]] || [[ $type_matches = false ]]; then
      c="defaults write $domain $key $type $value"
      bake "$c"
    fi
  done
}
rbenv () {
  if ! includes "$(command rbenv versions --bare )" $1; then
    bake "command rbenv install $1"
  fi
}


includes () {
  present=$(echo "$1" | grep -e "$2" > /dev/null)
  return $present
}

replace () {
  echo $(echo "$1" | sed -E 's|'"$2"'|'"$3"'|')
}

substring () {
  echo $(expr "$1" : $2)
}

get_field () {
  echo $(echo "$1" | awk '{print $'"$2"'}')
}

get_directory () {
  echo $(eval "echo $1")
}

include () {
  if [ -e "$scriptDir/$1" ]; then
    # if [ $operation = 'build' ]; then
    #   echo "$scriptDir/$1"
    # else
      . "$scriptDir/$1"
    # fi
  else
    echo "include: $scriptDir/$1: No such file or directory"
    exit 1
  fi
}

bake () {
  if [ $operation = 'install' ]; then
    echo "$(1)"
  elif [ $operation = 'print' ]; then
    echo "$1"
  fi
}
operation=$1
script=$2
scriptName=$(substring "/$script" '.*/\(.*\)')
scriptDir=$(substring "$script" '\(.*\)/.*')
echo "$scriptDir $scriptName"

include $scriptName