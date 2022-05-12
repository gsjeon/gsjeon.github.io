Kvm + Vagrant
=============



.. author:: Gwangseok Jeon
.. categories:: kvm, vagrant
.. tags:: kvm, vagrant, devenv
.. comments::

내 시험서버에 개발환경을 구성한다.

개발환경은 KVM + Vagrant 로 TACO + CloudPC 를 프로비저닝 하도록 하자.

.. more::

KVM 설치와 Vagrant 설치 방법은 생략한다.

My ENV
------

* OS = Debian 11 (Code Name : bullseye)
* Kernel = 5.10.0
* kvm = 5.2.0
    - qemu = 5.2.0 (Debian 1:5.2+dfsg-11+deb11u2)
    - libvirt = 7.0.0
* vagrant = 2.2.19
    - vagrant-libvirt = 0.8.2 (plugin)


KVM Setting
-----------

저장소는 다음과 같이 정의한다.::

   # cat pool-images.xml
   <pool type='dir'>
     <name>images</name>
     <target>
       <path>/data/kvm/images</path>
       <permissions>
         <mode>0755</mode>
         <owner>0</owner>
         <group>0</group>
       </permissions>
     </target>
   </pool>

   # virsh pool-define pool-images.xml
   # virsh pool-start images
   # virsh pool-autostart images

   # virsh pool-define pool-volumes.xml
   # virsh pool-start volumes
   # virsh pool-autostart volumes

   # virsh pool-define pool-iso.xml
   # virsh pool-start iso
   # virsh pool-autostart iso

   # virsh pool-list
    Name      State    Autostart
   -------------------------------
    default   active   no
    images    active   yes
    iso       active   yes
    volumes   active   yes

* images = VM 템플릿 이미지가 저장될 저장소
* volumes = VM 의 디스크가 저장될 저장소
* iso = ISO 이미지를 저장할 저장소


네트워크는 다음과 같이 정의한다.::

   $ cat net-service.xml
   <network>
       <name>service</name>
       <forward mode='nat'>
         <nat>
           <port start='1024' end='65535'/>
         </nat>
       </forward>
       <bridge name='virbr0' stp='on' delay='0'/>
       <ip address='100.100.100.1' netmask='255.255.255.0'>
         <dhcp>
           <range start='100.100.100.10' end='100.100.100.250'/>
         </dhcp>
       </ip>
   </network>

   # virsh net-define net-mgmt.xml
   # virsh net-start mgmt
   # virsh net-autostart mgmt

   # virsh net-define net-storage.xml
   # virsh net-start storage
   # virsh net-autostart storage

   # virsh net-define net-tunnel.xml
   # virsh net-start tunnel
   # virsh net-autostart tunnel

   # virsh net-define net-provider.xml
   # virsh net-start provider
   # virsh net-autostart provider

   # virsh net-define net-service.xml
   # virsh net-start service
   # virsh net-autostart service

   # virsh net-list
    이름       상태     자동 시작   Persistent
   ---------------------------------------------
    mgmt       활성화   예          예
    provider   활성화   예          예
    service    활성화   예          예
    storage    활성화   예          예
    tunnel     활성화   예          예

* mgmt = K8S/OpenStack Managemant Network
* storage = Ceph Public/Cluster
* tunnel = OpenStack self-service
* provider = OpenStack provider
* service = Spice/Portal Network


Vagrant Setting
---------------

Vagrant 튜토리얼
++++++++++++++++

먼저 base image 를 만든다.::

   $ virt-install --name=cloudx-os-2.0.7.tpl \
                  --os-type=Linux \
                  --os-variant=rhel7 \
                  --vcpus=1 \
                  --memory=1024 \
                  --cdrom=/data/kvm/iso/cloudx-os-2.0.7-x86_64.iso \
                  --disk path=/data/kvm/images/cloudx-os-2.0.7.qcow2,size=3 \
                  --network bridge:virbr1 \
                  --graphics vnc,listen=0.0.0.0,password=1234

* VNC 로 접속하여 OS 설치 완료!

 base images 생성 시 disk size 를 최대한 작게 설정하는게 좋다.
 box를 만들 때 virtual size 전체가 복사되어 저장소 낭비가 되며 필요시 동적으로
 늘릴 수 있기 때문에 작게 하는게 좋다. 

VM 을 Vagrant Box 로 freeze 한다.::

   $ virsh shutdown cloudx-os-2.0.7.tpl

   $ wget https://raw.githubusercontent.com/vagrant-libvirt/vagrant-libvirt/master/tools/create_box.sh 

   $ ./create_box.sh cloudx-os-2.0.7.qcow2
   {3}
   ==> Creating box, tarring and gzipping
   ./metadata.json
   ./Vagrantfile
   ./box.img
   Total bytes written: 1629952000 (1.6GiB, 395MiB/s)
   ==> cloudx-os-2.0.7.box created
   ==> You can now add the box:
   ==>   'vagrant box add cloudx-os-2.0.7.box --name cloudx-os-2.0.7'


* 이렇게 하면 vagrant 가 사용할 수 있도록 box 형태가 된다.

 주의사항: 

box 형태의 패키지 안에는 뭐가 들었나?::

   $ tar tvf cloudx-os-2.0.7.box
   -rw-r--r-- clex/clex        76 2022-05-11 15:54 ./metadata.json
   -rw-r--r-- clex/clex       220 2022-05-11 15:54 ./Vagrantfile
   -rw------- clex/clex 3221946368 2022-05-11 15:52 ./box.img

* medata.json 안에는 provider 가 libvirt 라는 것이 정의되어 있고,
* Vagrantfile 안에는 프로비저닝을 위한 설정들이 정의되어 있고,
* box.img 는 qcow2 파일이 압축되어 있다. 
* 아래에서 Vagrantfile 을 custom 하여 패키지를 다시 말아볼 것이다.

만든 box 를 로컬 저장소로 push 한다.::

   $ vagrant box add cloudx-os-2.0.7.box --name cloudx-os-2.0.7
   ==> box: Box file was not detected as metadata. Adding it directly...
   ==> box: Adding box 'cloudx-os-2.0.7' (v0) for provider:
       box: Unpacking necessary files from: file:///data/kvm/images/cloudx-os-2.0.7.box
   ==> box: Successfully added box 'cloudx-os-2.0.7' (v0) for 'libvirt'!

   $ vagrant box list
   cloudx-os-2.0.7 (libvirt, 0)
    
로컬 저장소로 push 하면 아래 경로에 parent 이미지가 저장된다.::

   $ ls -l ~/.vagrant.d/boxes/
   total 0
   drwxr-xr-x 3 clex clex 15 May 11 16:19 cloudx-os-2.0.7
    
* 만약, home 디렉토리에 용량이 별로 없고 box 가 쌓인다면 용량 초과 문제가
  발생할 수 있다.
* VAGRANT_HOME 환경변수를 재선언하여 바꿀 수 있다. (기본값이 ~/.vagrant.d)
* https://www.vagrantup.com/docs/other/environmental-variables


이제 box 가 있으니, VM 을 만들 수 있다.::

   $ mkdir jgs-lab
   $ cd jgs-lab/
   $ vagrant init cloudx-os-2.0.7
   $ vagrant up

   $ sudo virsh list --all
    Id   Name              State
   ---------------------------------
    1    jgs-lab_default   running

   $ vagrant status
   Current machine states:

   default                   running (libvirt)
   
* vagrant up 하면 box 로 부터 base 이미지를 만들고(/var/lib/libvirt/images/)
* base 이미지로 부터 스냅샷하여 실제 VM 에게 attach 할 volume 을 만든다.
* 볼륨은 Vagrantfile 내에 정의된 pool 에 만들어지게 된다.


 위 box 를 Vagrant Cloud 저장소에 업로드하여 형상관리가 가능하다.
 이것은 Docker Hub 와 매우 비슷하며 내가 만든 cloudx-os 도 Vagrant Cloud
 저장소에 업로드 해야겠다.

우선 `Vagrant Cloud <https://app.vagrantup.com/>`_ 에서 가입 후 개인 저장소를
만들자.

* 나의 경우 ``gsjeon/cloudx-os`` 로 만들었고 해당 저장소에 버전별로 형상관리를 할 것이다.



Custom Vagrant
+++++++++++++++

TACO 를 설치할 box 를 직접 만들어 provisioning 하니 문제가 있다.
* IP 를 가져오지 못하고 멈춘다. (dhcp: false 로 하였음)
* 이유는 box 내부에 dhcp client 가 설치되어 있아야 했다.

아~ 그냥 Vagrant Cloud 에서 Vagrant 용으로 제공해주는 official image 를 가져다
쓰자..


정석매니저님이 교육용으로 만든 파일을 수정하여 새롭게 만들었다.
* `Github <https://github.com/gsjeon/misc/tree/main/vagrant>`_  에 올려두었다

사용방법
^^^^^^^^

Git Clone.::

   ~# git clone https://github.com/gsjeon/misc.git   


디렉토리 만들고 소스 복사.::

   # mkdir /data/kvm/taco-lab
   # cd /data/kvm/taco-lab/
   # cp ~/misc/vagrant/vagrant/* .    

Vagrantfile 에서 환경변수 설정.::

   # vi Vagrantfile
   # -*- mode: ruby -*-
   # vi: set ft=ruby :

   ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

   Vagrant.configure("2") do |config|
     Control = 3 # max number of contrl nodes
     Compute = 2 # max number of compute nodes
     Ceph = 1 # max number of ceph nodes
     Zone = 'dev' # your zone name
     NetPrefixService = '100.100.100' # 1 ~ 3th octet IP
     NetPrefixMGMT = '1.1.1' # 1 ~ 3th octet IP
     NetPrefixStorage = '2.2.2' # 1 ~ 3th octet IP
     NetPrefixTunnel = '3.3.3' # 1 ~ 3th octet IP
     NetPrefixProvider = '4.4.4' # 1 ~ 3th octet IP
     NetSuffix = 1 # 4th octet IP

   config.vm.synced_folder "/data/kvm/cloudx-pkg", "/vagrant", type: "nfs"
   ...

* Control = 컨트롤러 노드의 개수
* Compute = 컴퓨트 노드의 개수
* Ceph = Ceph 노드의 개수
* Zone = 자신의 존 이름(아무렇게나)
* NetPrefixService = Portal/Spice 전용 네트워크의 대역 (/24로 가정하고 3 옥텟)
* NetPrefixMGMT = K8S/OpenStack 관리 네트워크의 대역 (/24로 가정하고 3 옥텟)
* NetPrefixStorage = Ceph Public/Cluster 네트워크의 대역 (/24로 가정하고 3 옥텟)
* NetPrefixTunnel = OpenStack selfservice 네트워크의 대역 (/24로 가정하고 3 옥텟)
* NetPrefixProvider = Provider 네트워크의 대역 (/24로 가정하고 3 옥텟)
* NetSuffix = 4 옥텟의 IP
* config.vm.synced_folder 는 호스트의 특정 디렉토리를 VM 에 공유하기 위해
  사용된다.
  - /data/kvm/cloudx-pkg 은 호스트의 디렉토리를 의미하고,
  - /vagrant 은 VM 에서 마운트할 마운트 포인트를 의미하고,
  - type: nfs 는 nfs 를 이용해 공유한다는 의미임

위와 같이 설정 후 vagrant up 한다.::

   # vagrant up

* 프로비저닝하는데 약간의 시간이 걸린다.

상태확인.::

   # vagrant status
   Current machine states:

   dev-control-1             running (libvirt)
   dev-control-2             running (libvirt)
   dev-control-3             running (libvirt)
   dev-compute-1             running (libvirt)
   dev-compute-2             running (libvirt)
   dev-ceph-1                running (libvirt)


SSH 접속방법.::

   # vagrant ssh dev-control-1
   [clex@dev-control-1 ~]$ ip a
   1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
       link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
       inet 127.0.0.1/8 scope host lo
          valid_lft forever preferred_lft forever
       inet6 ::1/128 scope host
          valid_lft forever preferred_lft forever
   2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
       link/ether 52:54:00:e4:06:62 brd ff:ff:ff:ff:ff:ff
       inet 100.100.100.127/24 brd 100.100.100.255 scope global dynamic eth0
          valid_lft 3482sec preferred_lft 3482sec
       inet6 fe80::5054:ff:fee4:662/64 scope link
          valid_lft forever preferred_lft forever
   3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
       link/ether 52:54:00:dc:ff:86 brd ff:ff:ff:ff:ff:ff
       inet 1.1.1.11/24 brd 1.1.1.255 scope global eth1
          valid_lft forever preferred_lft forever
       inet6 fe80::5054:ff:fedc:ff86/64 scope link
          valid_lft forever preferred_lft forever
   4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
       link/ether 52:54:00:ea:11:7e brd ff:ff:ff:ff:ff:ff
       inet 2.2.2.11/24 brd 2.2.2.255 scope global eth2
          valid_lft forever preferred_lft forever
       inet6 fe80::5054:ff:feea:117e/64 scope link
          valid_lft forever preferred_lft forever
   5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
       link/ether 52:54:00:26:48:20 brd ff:ff:ff:ff:ff:ff
       inet 3.3.3.11/24 brd 3.3.3.255 scope global eth3
          valid_lft forever preferred_lft forever
       inet6 fe80::5054:ff:fe26:4820/64 scope link
          valid_lft forever preferred_lft forever
   6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
       link/ether 52:54:00:de:04:70 brd ff:ff:ff:ff:ff:ff
       inet6 fe80::5054:ff:fede:470/64 scope link
          valid_lft forever preferred_lft forever

   [clex@dev-control-1 ~]$ cat /etc/hosts
   127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
   ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
   1.1.1.11 dev-control-1
   1.1.1.12 dev-control-2
   1.1.1.13 dev-control-3
   1.1.1.21 dev-compute-1
   1.1.1.22 dev-compute-2
   1.1.1.31 dev-ceph-1

* vagrant ssh <VM명> 으로 접속하면 위와 같이 접속된다.
* VM 내부에서 보면 Vagrantfile 에 정의한대로 IP 설정이 자동으로 되어있다.
* vagrant ssh 로 접속 가능한 이유는 Vagrantfile 내에 로컬 터널링 하도록
  설정되어 있다. 그래서 호스트 600xx 포트와 VM 22포트로 터널링된다.
* Service 대역의 IP는 외부로 nat 되어 통신되는 IP 이고 DHCP 유동 IP로 세팅된다.
* 나머지 IP는 Net Prefix/Suffix 의 변수에 따라 고정 IP로 할당된다. 
  - 필요시 자유롭게 바꿔도 된다.

공유파일 사용방법.::

   [clex@dev-control-1 ~]$ sudo mount /vagrant/

   [clex@dev-control-1 ~]$ df -hH /vagrant
   Filesystem                          Size  Used Avail Use% Mounted on
   100.100.100.1:/data/kvm/cloudx-pkg  930G   12G  918G   2% /vagrant
    
* fstab 에 호스트의 볼륨을 noauto 로 마운트 하도록 해두었다.
* 필요시에만 mount 하여 필요한 파일을 공유하면 된다.






