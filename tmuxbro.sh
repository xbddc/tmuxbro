#!/bin/sh

show_menu=1
do_multicast=0
tagged_pane=""
curr_pane="%1"
next_pane=""
prev_pane=""
pane_list=""

toggle_menu () {
  show_menu=$(($(($show_menu+1))%2))
}

func_menu () {
  clear
  if [ $show_menu = 1 ]; then
    echo "========[ tmuxbro v0.2 ]========"
    echo "[1;32m[F2][m: go previous window"
    echo "[1;32m[F3][m: go next window"
    echo "[1;32m[F4][m: remove current window"
    echo "[1;32m[F5][m: tag/untag current window"
    echo "[1;32m[F6][m: tag/untag all windows"
    echo "[1;32m[F7][m: toggle multicast"
    echo "[1;32m[F8][m: add host"
    echo "[1;32m[F9][m: show/hide menu"
    echo "[1;32m[F12][m: quit program"
    echo "================================"
  else
    echo "[1;32m[F9][m: show/hide menu"
  fi

  get_pane_list
  list=`tmux list-panes -a -t ssh-$sid -F "#D #{pane_start_command}" | grep -v '^%0 ' | sort -k2 -t% -n`
  list=`echo "$list" | sed "s:^$curr_pane \(.*\)$:$curr_pane [1;42m\\1[m:g"`
  if [ $do_multicast = 0 ]; then
    for x in $tagged_pane; do
      list=`echo "$list" | sed "s:^$x \(.*\)$:$x \\1 [1;37m*[m:g"`
    done
  else
    for x in $tagged_pane; do
      list=`echo "$list" | sed "s:^$x \(.*\)$:$x \\1 [1;37;41m*[m:g"`
    done
  fi

  OLD_IFS=$IFS; IFS=\n
  echo $list | sed "s:^%\([0-9]*\) :\[\\1\] :g"
  IFS=$OLD_IFS

  if [ $do_multicast = 1 ]; then
    echo -n "\n[1;41m!!! MULTICAST MODE !!![m"
  fi
}

get_pane_list () {
  pane_list=`tmux list-panes -a -t ssh-$sid -F "#D" | grep -v '^%0$' | sort -k2 -t% -n`
  OLD_IFS=$IFS; IFS=\n
  prev_pane=`echo $pane_list | grep -B1 "^$curr_pane$" | head -n1`
  next_pane=`echo $pane_list | grep -A1 "^$curr_pane$" | tail -n1`
  IFS=$OLD_IFS
}

get_keystroke () {
  old_stty_settings=`stty -g`
  stty -echo raw
  echo "`dd count=1 2> /dev/null`"
  stty $old_stty_settings
}

kill_session () {
  echo "\nclose all remote connections?"
  echo -n "([y]es/[n]o/[c]ancel) "
  n=`get_keystroke`
  if [ "$n" != "n" ] && [ "$n" != "y" ]; then
    return
  elif [ "$n" = "y" ]; then
    echo -n "killing session ... "
    while [ 1 ]; do
      tmux has-session -t ssh-$sid 2>/dev/null
      if [ $? != 0 ]; then
        break
      else
        tmux kill-session -t ssh-$sid
      fi
    done
  else
    tmux detach
  fi

  echo "bye."
  exit 0
}

join_pane () {
  tmux join-pane -s $1 -t %0 -h -d
  adj_width=$(( `tmux list-pane -a -F "#{pane_width} #D" | grep %0 | cut -d\  -f1`-32 ))
  tmux resize-pane -t $curr_pane -L $adj_width
}

create_window () {
  tmux new-window -d -t ssh-$sid -n "$1" "$1"
}

prev_window () {
  if [ "$curr_pane" != "$prev_pane" ]; then
    tmux break-pane -s $curr_pane -d
    curr_pane=$prev_pane
    join_pane $curr_pane
  fi
}

next_window () {
  if [ "$curr_pane" != "$next_pane" ]; then
    tmux break-pane -s $curr_pane -d
    curr_pane=$next_pane
    join_pane $curr_pane
  fi
}

del_window () {
  echo -n "\nremove this window? (y/n) "
  n=`get_keystroke`
  if [ "$n" = "y" ]; then
    tmux kill-pane -t $curr_pane
    if [ "$curr_pane" != "$prev_pane" ]; then
      curr_pane=$prev_pane
      join_pane $curr_pane
    elif [ "$curr_pane" != "$next_pane" ]; then
      curr_pane=$next_pane
      join_pane $curr_pane
    else
      curr_pane=""
    fi
  fi
}

add_window () {
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
  if [ $do_multicast = 1 ]; then
   echo "$tagged_pane" | tr " " "\n" | xargs -I{} tmux send-keys -t {} "$@"
  else
    tmux send-keys -t $curr_pane "$@"
  fi
}

tag_untag_all_windows () {
  tagged_pane=`echo "$tagged_pane" | tr " " "\n" | grep -v ^$ | sort | tr "\n" " "`
  pane_list_tmp=`echo "$pane_list" | tr "\n" " "`
  if [ "$pane_list_tmp" = "$tagged_pane" ]; then
    tagged_pane=""
  else
    tagged_pane=$pane_list_tmp
  fi
}

tag_untag_window () {
  new_tagged_pane=""
  found=0

  for x in $tagged_pane; do
    if [ "$x" = "$curr_pane" ]; then
      found=1
    else
      new_tagged_pane="$x $new_tagged_pane"
    fi
  done

  if [ $found = 1 ]; then
    tagged_pane=$new_tagged_pane
  else
    tagged_pane="$curr_pane $new_tagged_pane"
  fi
}

toggle_multicast () {
  do_multicast=$(($(($do_multicast+1))%2))
  if [ $do_multicast = 1 ]; then
    tmux set-window-option -t ssh-$sid status-bg red 1>/dev/null
  else
    tmux set-window-option -t ssh-$sid status-bg green 1>/dev/null
  fi
}

if [ ! -f `which tmux` ]; then
  echo "$0: tmux not found"
  exit 1
fi

#phase1
if [ "$1" != "tmuxbro_phase2" ]; then
  tmux new-session -s ssh-$$ "sh $0 tmuxbro_phase2 $$ $1"
  sleep 1
  tmux set-option -t ssh-$$ remain-on-exit on 1>/dev/null
  exit
fi

#phase2
sid=$2
host_file=$3

if [ ! -z $host_file ] && [ -f $host_file ]; then
  for host in `cat $host_file`; do 
    create_window "ssh $host"
  done
else
  add_window force
fi

tmux select-window -t 0
join_pane $curr_pane
func_menu

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
    \[20~) #F9
      toggle_menu
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
