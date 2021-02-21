---
layout: post
title: OpenStack config drive detach 방법
author: Gwangseok Jeon
date: 2021-01-22 10:58 +0900
last_modified_at: 2021-01-22 16:18:25 +0900
tags:
- openstack
- config-drive
categories:
- openstack
toc:  true
---

개요
------

오픈스택은 인스턴스에게 메타데이터를 전달하기 위해 2가지 방식을 지원한다.

1. config-drive : 인스턴스에 cdrom(iso9660)이나, 디스크(vfat) 장치를 통해
   메타데이터를 담아 전달하는 방식
2. metadata-service : 장치 필요 없이 네트워크를 통해 metadata api 를 호출하여
   가져오는 방식


나의 경우 위 두 방식 중 config-drvie 를 사용하는 중이며, 
인스턴스 최초 부팅시 config-drive 에 담긴 메타데이터와 유저데이터를
기반으로 ad join 스크립트를 실행시켜 자동 ad join 을 하도록 했다.


하지만 인스턴스를 매번 부팅할때마다 config-drvie 장치가 항상 붙어있고 그 안에
민감한 정보가 있기 때문에 config-drive 를 떼내고 싶다.


어떻게 detach 해야 할지 알아보자.


1.) config-drvie 장치 생성시점
-------------------------------------

먼저 Config-Drvie 가 어떤 경우 붙게되는지 알아보자.

노바는 "인스턴스 생성 시점" 에 Config-Drive 를 붙여줄지? 말지? 를 결정한다.

아래 2가지 경우가 있다.

1. 인스턴스 생성시 (openstack server create) "--config-drvie true" 옵션을 넣어주면 Config-Drive 를 붙여준다.
2. 노바의 설정 중 "force_config_drive: Ture" 이면, 따로 옵션을 안줘도 인스턴스를 만들 때 무조건 Config-Drive 를 붙여준다.


2.) Config-Drive 장치 판단 여부
--------------------------------

노바가 인스턴스에 Config-Drive를 붙여줄 지 어떤 값을 보고 판단하는지 알아보자.
```
MariaDB [nova]> select hostname, config_drive from instances;
+-----------------+--------------+
| hostname        | config_drive |
+-----------------+--------------+
| test            |              |
| test-1          |              |
| cloudbase-test  | True         |
| jgs-test1       | True         |
| jgs-test1       | True         |
| jgs-test2       | True         |
+-----------------+--------------+
```
* nova 데이터베이스의 instances 테이블에 config_drive 칼럼의 값이 True 이면,
* 해당 인스턴스는 무조건 Config-Drive 를 가지게 된다.

> 무조건 Config-Drive 를 가지게 된다는 설명을 덫붙이자면 libvirt domain xml
> 파일에 config drive 장치가 고정되어 매번 부팅시 config drvie 를 가지게 된다.


3.) Config-Drive 장치 Detach 
-----------------------------

CD-ROM 포맷의 경우

```
()[root@stage-compute-03 /]# virsh detach-disk instance-0000356f hda
error: Failed to detach disk
error: Operation not supported: disk device type 'cdrom' cannot be detached
```
* 위와 같이 "cdrom" 장치는 라이브로 떼어내는 것을 libvirt가 지원하지 않는다.


vfat 포맷의 경우

```
()[root@stage-compute-03 /]# virsh detach-disk instance-0000004a /var/lib/nova/instances/3fe15307-9202-413d-a4ed-ad3e2aac298e/disk.config --live --persistent
Disk detached successfully
```
* vfat 포맷의 경우 disk 장치로 인식되기 때문에 라이브 detach 가능하다.

> 하지만 live detach 후에도 리부팅하면 여전히 config drive 가 붙어있다.
> 즉, Config-Drvie 는 "인스턴스 생성시점" 에서 True 로 정해지면 떼어낼 수 없었다..

정말 떼어내려면 DB를 직접 수정해야 했다.
```
MariaDB [nova]> update instances set config_drive=NULL where uuid='c51476b7-c2d2-465d-bec5-56d4413a3fd3';
```
* 위와같이 DB를 직접 수정 후 "재부팅" 을 하면, CD-ROM 장치가 detach 된다.

> libvirt domain xml 에 고정된 config drvie 설정이 사라짐을 확인했다.


DB 를 직접 수정하지 않고 config-drvie detach API를 제공하지는 않을까?
* 노바 API 문서를 보았으나, API를 제공하지 않는다.

