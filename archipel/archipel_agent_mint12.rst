Installing agent on linux mint 12
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

::
 
 sudo apt-get install build-essential python-dev gnutls-bin libvirt-bin kvm python-setuptools python-numpy apscheduler python-imaging python-sqlalchemy 

 wget http://downloads.sourceforge.net/project/xmpppy/xmpppy/0.5.0-rc1/xmpppy-0.5.0rc1.tar.gz
 tar zxvf xmpppy-0.5.0rc1.tar.gz
 cd xmpppy-0.5.0rc1
 sudo python setup.py install

 cd ..
 wget http://nightlies.archipelproject.org/latest-archipel-agent.tar.gz
 tar zxvf latest-archipel-agent.tar.gz
 cd latest-archipel-agent
 sudo ./buildAgent -d
 sudo archipel-initinstall  

