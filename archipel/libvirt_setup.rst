Enable TLS and TCP listen
~~~~~~~~~~~~~~~~~~~~~~~~~

Edit the file : /etc/init/libvirt-bin.conf

Change the line 

 ::
 env libvirtd_opts="-d"

by this one 

 ::
 env libvirtd_opts="-d -l"

Edit /etc/libvirt/libvirtd.conf

Uncomment the following lines 

  :: 
  listen_tls = 1
  listen_tcp = 1

Stop and start libvirt

  ::
  service libvirt-bin stop
  service libvirt-bin start

Check that everithing is ok with the following command

  ::
  ps -aef | grep libvirtd

you should see a line like this one 

  :: 
  root     22012 16275  0 18:53 pts/1    00:00:00 grep --color=auto libvirtd

