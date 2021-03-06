Setup PKI for libvirt and enable remote TLS connections
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

see pki/README.rst for a tutorial of creating a pki

Enable TLS and TCP listen
~~~~~~~~~~~~~~~~~~~~~~~~~

Edit the file : /etc/default/libvirt-bin

Change the line 

::

 libvirtd_opts="-d"

by this one 

::

 libvirtd_opts="-d -l"

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

  root     22242     1  1 Nov30 ?        00:21:35 /usr/sbin/libvirtd -d -l

Enable VNC
~~~~~~~~~~

Edit the file /etc/libvirt/qemu.conf

uncomment the following lines

::

 vnc_listen = "0.0.0.0"

Stop and start libvirt

::

  service libvirt-bin stop
  service libvirt-bin start

