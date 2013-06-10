tmuxbro
=======

`tmuxbro` is a ssh multiplexer written in shell script, 
it uses `tmux` as its terminal emulator backend. 
`tmuxbro` implements most functions in `omnitty`, 
which is a curses-based ssh multiplexer program on UNIX-like systems.

<pre>
$ cat /path/to/host_list
root@10.210.201.81
root@10.210.201.82
root@10.210.201.83
...

$ ./tmuxbro.sh /path/to/host_list
</pre>

Screenshot:
![screenshot](http://img.ncu.cc/1370863551.60.png)
