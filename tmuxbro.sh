#!/bin/sh

do_multicast=0
tagged_window=""

func_menu () {
  clear
  echo "==[ tmuxbro v0.1 ]=============="
  echo "[1;32m[F2][m: go previous window"
  echo "[1;32m[F3][m: go next window"
  echo "[1;32m[F4][m: remove current window"
  echo "[1;32m[F5][m: tag/untag current window"
  echo "[1;32m[F6][m: tag/untag all windows"
  echo "[1;32m[F7][m: toggle multicast"
  echo "[1;32m[F8][m: add host"
  echo "[1;32m[F12][m: quit program"
  echo "================================"

  curr=`tmux list-windows -t ssh-$$ | grep \(active\) | cut -d: -f1`
  list=`tmux list-windows -t ssh-$$ | grep -Eo '.+\[[0-9x]+\]'`
  list=`echo "$list" | sed "s/^$curr: \(.*\)$/$curr: [1;42m\1[m/g"`

  for x in $tagged_window; do
    if [ $do_multicast = 1 ]; then
      list=`echo "$list" | sed "s/^$x: \(.*\)$/$x: \1[1;37;41m*[m/g"`
    else
      list=`echo "$list" | sed "s/^$x: \(.*\)$/$x: \1[1;37m*[m/g"`
    fi
  done

  OLD_IFS=$IFS; IFS=\n
  echo $list
  IFS=$OLD_IFS

  if [ $do_multicast = 1 ]; then
    echo -n "[1;41m!!! MULTICAST MODE !!![m"
  fi
}

get_keystroke () {
  old_stty_settings=`stty -g`
  stty -echo raw
  echo "`dd count=1 2> /dev/null`"
  stty $old_stty_settings
}

check_session () {
  tmux has-session -t ssh-$$ 2>/dev/null
  if [ $? != 0 ]; then
    echo "session not found, quit."
    exit 3
  fi

  list=`tmux list-window -t ssh-$$ | cut -d: -f1`
  new_tagged_window=""
  for x in $tagged_window; do
    for y in $list; do
      if [ "$x" = "$y" ]; then
        new_tagged_window="$x $new_tagged_window"
        break
      fi
    done
  done
  tagged_window=$new_tagged_window
}

attach_session () {
  echo -n "attaching session ... "
  while [ 1 ]; do
    tmux has-session -t ssh-$$ 2>/dev/null
    if [ $? = 0 ]; then
      break
    else
      tmux new-session -d -s ssh-$$
      sleep 1
      tmux set-option -t ssh-$$ remain-on-exit on 1>/dev/null
    fi
  done
  echo "done."
}

kill_session () {
  echo -n "\ndisconnect from each host? (y/n/c) "
  n=`get_keystroke`
  if [ "$n" != "n" ] && [ "$n" != "y" ]; then
    return
  elif [ "$n" = "y" ]; then
    echo -n "killing session ... "
    while [ 1 ]; do
      tmux has-session -t ssh-$$ 2>/dev/null
      if [ $? != 0 ]; then
        break
      else
        tmux kill-session -t ssh-$$
      fi
    done
  fi
  echo "bye."
  exit 0
}

create_window () {
  check_session
  tmux new-window -t ssh-$$ -n "$1" "$1"
}

remove_window_0 () {
  check_session
  tmux kill-window -t ssh-$$:0
}

prev_window () {
  check_session
  tmux select-window -t ssh-$$ -p
}

next_window () {
  check_session
  tmux select-window -t ssh-$$ -n
}

del_window () {
  check_session
  echo -n "\nremove this window? (y/n) "
  n=`get_keystroke`
  if [ "$n" = "y" ]; then
    tmux kill-window -t ssh-$$
  fi
}

add_window () {
  check_session
  while [ 1 ]; do
    read -p "add a host: " host
    if [ "$host" != "" ]; then
      create_window "ssh $host"
      break
    elif [ "$1" != "force" ]; then
      break
    fi
  done
}

multicast () {
  check_session
  if [ $do_multicast = 1 ]; then
    echo "$tagged_window" | tr " " "\n" | xargs -I{} tmux send-keys -t ssh-$$:{} "$@"
  else
    tmux send-keys -t ssh-$$ "$@"
  fi
}

tag_untag_all_windows () {
  check_session
  list=`tmux list-windows -t ssh-$$ | cut -d: -f1 | sort | tr "\n" " "`
  tagged_window=`echo "$tagged_window" | tr " " "\n" | grep -v ^$ | sort | tr "\n" " "`
  if [ "$list" = "$tagged_window" ]; then
    tagged_window=""
  else
    tagged_window=$list
  fi
}

tag_untag_window () {
  check_session
  new_tagged_window=""
  found=0
  curr=`tmux list-windows -t ssh-$$ | grep \(active\) | cut -d: -f1`

  for x in $tagged_window; do
    if [ "$x" = "$curr" ]; then
      found=1
    else
      new_tagged_window="$x $new_tagged_window"
    fi
  done

  if [ $found = 1 ]; then
    tagged_window=$new_tagged_window
  else
    tagged_window="$curr $new_tagged_window"
  fi
}

toggle_multicast () {
  do_multicast=$(($(($do_multicast+1))%2))
  if [ $do_multicast = 1 ]; then
    tmux set-window-option -t ssh-$$ status-bg red 1>/dev/null
  else
    tmux set-window-option -t ssh-$$ status-bg green 1>/dev/null
  fi
}

if [ "$1" = "-h" ]; then
  echo "usage: $0 [/path/to/host_list]"
  exit 0
fi

if [ ! -f `which tmux` ]; then
  echo "$0: tmux not found"
  exit 1
fi

attach_session

if [ ! -z $1 ] && [ -f $1 ]; then
  list=`cat $1`
  for host in $list; do 
    create_window "ssh $host"
  done
else
  add_window force
fi

remove_window_0
func_menu
echo "focus on this terminal to pass cmds"

if [ -x "`which x-terminal-emulator`" ]; then
  x-terminal-emulator -e tmux attach-session -t ssh-$$ 2>/dev/null &
elif [ -x "`which gnome-terminal`" ]; then
  gnome-terminal -e "tmux attach-session -t ssh-$$" 2>/dev/null &
elif [ -x "`which xterm`" ]; then
  xterm -e "tmux attach-session -t ssh-$$" 2>/dev/null &
else
  echo "please open a new terminal and run 'tmux attach-session -t ssh-$$' to get hosts output"
fi

while [ 1 ]; do
  m=`get_keystroke`
  case "$m" in
    OQ|\[12~) #F2
      prev_window
    ;;
    OR|\[13~) #F3
      next_window
    ;;
    OS|\[14~) #F4
      del_window
    ;;
    \[15~) #F5
      tag_untag_window
    ;;
    \[17~) #F6
      tag_untag_all_windows
    ;;
    \[18~) #F7
      toggle_multicast
    ;;
    \[19~) #F8
      add_window
    ;;
    \[24~) #F12
      kill_session
    ;;
    *)
      multicast "$m"
      continue
    ;;
  esac
  func_menu
done
