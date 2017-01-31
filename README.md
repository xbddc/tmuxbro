tmuxbro
=======

`tmuxbro` is a ssh multiplexer written in shell script, 
using `tmux` as the terminal emulator backend.

`tmuxbro` can be a simple alternative utility to `omnitty`,
which is a curses-based ssh multiplexer tool on UNIX-like systems.

<pre>
$ cat /path/to/host_list
root@172.17.0.3
root@172.17.0.4
root@172.17.0.5
root@172.17.0.6
...

$ ./tmuxbro.sh /path/to/host_list
</pre>

Screenshot:

![screenshot](https://raw.githubusercontent.com/xbddc/tmuxbro/master/screenshot.jpg)
