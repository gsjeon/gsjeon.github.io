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
       <bridge name='virbr5' stp='on' delay='0'/>
       <ip address='5.5.5.1' netmask='255.255.255.0'>
         <dhcp>
           <range start='5.5.5.10' end='5.5.5.250'/>
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



Custom Box
++++++++++

위에서 간략 사용 방법을 알았으니 이제 개발용 환경으로 프로비저닝을 위한 custom box 를 만들자.::

   # cat Vagrantfile
   # -*- mode: ruby -*-
   # vi: set ft=ruby :

   ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

   Vagrant.configure("2") do |config|
     Control = 3 # max number of contrl nodes
     Compute = 2 # max number of compute nodes
     Ceph = 1 # max number of ceph nodes
     Ver = '2.0.7' # cloudx-os version
     Zone = 'dev' # your zone name
     Num = 1 # 4th octet IP prefix number

   config.vm.synced_folder '.', '/vagrant', disabled: true

     #==============#
     # ControlNodes #
     #==============#

     (1..Control).each do |i|
       config.vm.define "#{Zone}-control-#{i}" do |cfg|
         cfg.vm.box = "cloudx-os-2.0.7"
         cfg.vm.provider "libvirt" do |vb|
           vb.cpus = 16
           vb.memory = 32768
           vb.management_network_name = "service"
           vb.management_network_address = "5.5.5.#{Num}#{i}/24"
           vb.management_network_mac = "52:54:00:3f:2a:a#{i}"
           vb.storage_pool_name = "volumes"
           vb.machine_virtual_size = 500
           vb.graphics_ip = "0.0.0.0"
         end
         cfg.vm.host_name = "#{Zone}-control-#{i}"
         cfg.vm.network "private_network", ip: "1.1.1.#{Num}#{i}",
           libvirt__network_name: "mgmt",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "2.2.2.#{Num}#{i}",
           libvirt__network_name: "storage",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
           #libvirt__mtu: "9000"
         cfg.vm.network "private_network", ip: "3.3.3.#{Num}#{i}",
           auto_config: false,
           libvirt__network_name: "tunnel",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "4.4.4.#{Num}#{i}",
           libvirt__network_name: "provider",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "forwarded_port", guest: 22, host: "600#{Num}#{i}", host_ip: "127.0.0.1"
         cfg.vm.provision "shell", path: "bootstrap.sh", args: [Control, Compute, Ceph]
       end
     end

     #================#
     # Comopute Nodes #
     #================#

     (1..Compute).each do |i|
       config.vm.define "#{Zone}-compute-#{i}" do |cfg|
         cfg.vm.box = "cloudx-os-2.0.7"
         cfg.vm.provider "libvirt" do |vb|
           vb.cpus = 16
           vb.memory = 32768
           vb.nested = true
           vb.cpu_mode = "host-passthrough"
           vb.management_network_name = "service"
           vb.management_network_address = "5.5.5.#{Num + 1}#{i}/24"
           vb.management_network_mac = "52:54:00:3f:2a:b#{i}"
           vb.storage_pool_name = "volumes"
           vb.graphics_ip = "0.0.0.0"
         end
         cfg.vm.host_name = "#{Zone}-compute-#{i}"
         cfg.vm.network "private_network", ip: "1.1.1.#{Num + 1}#{i}",
           libvirt__network_name: "mgmt",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "2.2.2.#{Num + 1}#{i}",
           libvirt__network_name: "storage",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
           #libvirt__mtu: "9000"
         cfg.vm.network "private_network", ip: "3.3.3.#{Num + 1}#{i}",
           auto_config: false,
           libvirt__network_name: "tunnel",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "4.4.4.#{Num + 1}#{i}",
           libvirt__network_name: "provider",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "forwarded_port", guest: 22, host: "600#{Num + 1}#{i}", host_ip: "127.0.0.1"
         cfg.vm.provision "shell", path: "bootstrap.sh", args: [Control, Compute, Ceph]
       end
     end

     #============#
     # Ceph Nodes #
     #============#

     (1..Ceph).each do |i|
       config.vm.define "#{Zone}-ceph-#{i}" do |cfg|
         cfg.vm.box = "cloudx-os-2.0.7"
         cfg.vm.provider "libvirt" do |vb|
           vb.cpus = 8
           vb.memory = 16384
           vb.management_network_name = "service"
           vb.management_network_address = "5.5.5.#{Num + 2}#{i}/24"
           vb.management_network_mac = "52:54:00:3f:2a:c#{i}"
           vb.storage :file, :device => 'sdb', :size => '300G'
           vb.storage :file, :device => 'sdc', :size => '300G'
           vb.storage :file, :device => 'sdd', :size => '300G'
           vb.storage_pool_name = "volumes"
           vb.graphics_ip = "0.0.0.0"
         end
         cfg.vm.host_name = "#{Zone}-ceph-#{i}"
         cfg.vm.network "private_network", ip: "1.1.1.#{Num + 2}#{i}",
           libvirt__network_name: "mgmt",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "2.2.2.#{Num + 2}#{i}",
           libvirt__network_name: "storage",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
           #libvirt__mtu: "9000"
         cfg.vm.network "private_network", ip: "3.3.3.#{Num + 2}#{i}",
           auto_config: false,
           libvirt__network_name: "tunnel",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "private_network", ip: "4.4.4.#{Num + 2}#{i}",
           libvirt__network_name: "provider",
           libvirt__forward_mode: "none",
           libvirt__dhcp_enabled: "false"
         cfg.vm.network "forwarded_port", guest: 22, host: "600#{Num + 2}#{i}", host_ip: "127.0.0.1"
         cfg.vm.provision "shell", path: "bootstrap.sh", args: [Control, Compute, Ceph]
       end
     end


Reference
+++++++++

* https://github.com/vagrant-libvirt/vagrant-libvirt
* https://www.vagrantup.com/docs/boxes/base#default-user-settings
* https://leyhline.github.io/2019/02/16/creating-a-vagrant-base-box/


