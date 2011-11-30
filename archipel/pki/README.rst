Introduction
~~~~~~~~~~~~

This is a handy script to ease the creation of TLS certificate when using libvirt remote connections (qemu+tls)

Usage
~~~~~

::

 Usage : pki.sh -c [action] -o organization -n hostname | -z | -h  
 -c configure pki
 actions :
  ca : create a certificate of authority
  server : create server cert and key
  client : create client cert and key
 -n hostname 
 -z clear all configuration
 -h Show help 

Exemple
~~~~~~~

create certificate for server1 (server1 is the FQDN of the host)

::

 pki -c ca -o FROGLAB
 pki -c server -o froglab -n server1
 pki -c client -o froglab -n server1

this result in the following structure

::

 FROGLAB/
 ├── ca
 │   ├── cacert.pem
 │   └── cakey.pem
 ├── ca.info
 └── server1
     ├── client.info
     ├── pki
     │   ├── CA
     │   │   └── cacert.pem
     │   └── libvirt
     │       ├── clientcert.pem
     │       ├── private
     │       │   ├── clientkey.pem
     │       │   └── serverkey.pem
     │       └── servercert.pem
     └── server.info

just copy FROGLAB/server1/pki in /etc/pki on server1 and restart libvirt and stop/start libvirt

create certificate for another server (server2)

::

 pki -c server -o froglab -n server2
 pki -c client -o froglab -n server2

jsut copy FROGLAB/server2/pki in /etc/pki on server1 and restart libvirt and stop/start libvirt

now server1 and server2 are now able to connect each other remotly. 
test it with :

::

 virsh -c qemu+tls://server1/system from server2
 virsh -c qemu+tls://server2/system from server1

Do not forget to enable tls and listen in libvirt configuration (http://wiki.libvirt.org/page/TLSDaemonConfiguration)

