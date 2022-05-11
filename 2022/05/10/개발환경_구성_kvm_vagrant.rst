개발환경 구성(kvm + vagrant)
============================



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

   # cat net-mgmt.xml
   <network>
       <name>mgmt</name>
       <forward mode="bridge" />
       <bridge name="virbr1" />
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

Vagrant box 만들기
++++++++++++++++++

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

base image 로 ssh 접속을 위해 호스트의 key를 copy한다.::

   $ ssh-keygen
   $ ssh-copy-id clex@1.1.1.2

* 1.1.1.2 IP는 VM 의 IP임

VM 을 Vagrant Box 로 freeze 한다.::

   $ virsh shutdown cloudx-os-2.0.7.tpl

   $ wget https://raw.githubusercontent.com/vagrant-libvirt/vagrant-libvirt/master/tools/create_box.sh 

   $ $ ./create_box.sh cloudx-os-2.0.7.qcow2
   {500}
   ==> Creating box, tarring and gzipping
   ./metadata.json
   ./Vagrantfile
   ./box.img
   Total bytes written: 1969807360 (1.9GiB, 405MiB/s)
   ==> cloudx-os-2.0.7.box created
   ==> You can now add the box:
   ==>   'vagrant box add cloudx-os-2.0.7.box --name cloudx-os-2.0.7'

* 이렇게 하면 vagrant 가 사용할 수 있도록 box 형태가 된다.

위 box 를 로컬 저장소로 add 한다.::

   $ vagrant box add cloudx-os-2.0.7.box --name cloudx-os-2.0.7
   ==> box: Box file was not detected as metadata. Adding it directly...
   ==> box: Adding box 'cloudx-os-2.0.7' (v0) for provider:
       box: Unpacking necessary files from: file:///data/kvm/images/cloudx-os-2.0.7.box
   ==> box: Successfully added box 'cloudx-os-2.0.7' (v0) for 'libvirt'!   

   $ vagrant box list
   cloudx-os-2.0.7 (libvirt, 0)





Reference
+++++++++

* https://github.com/vagrant-libvirt/vagrant-libvirt
* https://www.vagrantup.com/docs/boxes/base#default-user-settings
* https://leyhline.github.io/2019/02/16/creating-a-vagrant-base-box/




