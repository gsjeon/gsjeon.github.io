---
layout: post
title: NetApp NFS 기능 시험 with cinder
author: Gwangseok Jeon
date: 2020-11-11 10:58 +0900
last_modified_at: 2020-11-12 16:18:25 +0900
tags:
- openstack
- netapp
categories:
- openstack
- netapp
toc:  true
---


NetApp NFS 도입 검토중에 있다.


문서상 Cinder 는 백엔드로 NetApp NFS 를 지원하는 것을 확인했다.


아래 순서도는 Cinder 에서 NetApp NFS 를 사용할 때 볼륨이 만들어지는 과정을
나타내는 순서도다.


순서도를 보면 볼륨 생성시 경우에 따라 3가지 결과로 나뉘어진다.

각각의 경우를 테스트하여 효율적인 볼륨 생성을 가능 하도록 한다.

1. Cinder 에 이미지 캐시가 이미 존재하는 경우 - [Netapp Flexclone 구성/검증](https://gsjeon.github.io/openstack/netapp/2020/11/11/netapp-flexclone/)
2. Cinder 에 이미지 캐시가 없지만, Glance 저장소와 동일한 경우 - [Create volume directly from image. (skip cache image)](https://gsjeon.github.io/openstack/netapp/2020/11/11/netapp-direct-clone-image/)
3. Cinder 에 이미지 캐시가 없고, Glance 저장소와 동일하지 않지만, CopyOffload 기능이 활성화 된 경우 - [Copy Offload Tools 구성/검증](https://gsjeon.github.io/openstack/netapp/2020/11/11/netapp-copyoffload/)


![netapp-flow](/images/2020-11-11-netapp-summary/netapp-flow.PNG)
