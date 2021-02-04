---
layout: post
title: OpenStack Metadata-Service timed out!
author: Gwangseok Jeon
date: 2021-02-01 10:58 +0900
last_modified_at: 2021-02-01 16:18:25 +0900
tags:
- openstack
- metadata
- 기술지원
categories:
- openstack
- 기술지원
toc:  true
---

최근 오픈스택 Config-Drive 에서 Metada-Service 로 변경하였다.


개발 당시 검증할 때 특별히 문제가 없었는데, Production 에 적용하니 문제가
발생한다.


장애증상
---------

* Windows VM 을 만든다.
* Windows VM 은 부팅시 CloudBase-Init 이 실행된다.
* CloudBase-Init 은 user-data plugin 을 호출한다.
* user-data pluing 은 오픈스택 metadata-service 를 호출한다.
* metadata 서버는 응답하지 않아 "Timed out" 이 발생한다.

> 대체 왜 Metadata Service 가 작동하지 않는걸까?


장애분석
---------

1.) VM 을 만들면, VM은 메타데이터 서비스 호출을 위해 아래와 같이 라우팅 테이블이
셋팅된다.


![route](/images/route.JPG){: width="800" height="400"}

* 메타데이터 서버(169.254.169.254) 로 가려면 게이트웨이(192.168.207.2) 를 거쳐
  가도록 라우팅 테이블이 셋팅된 모습이다.

2.) 메타데이터 서버로 가기 위한 게이트웨이(192.168.2072.)는 DHCP 서버의 IP 이다.

![route](/images/dhcp-mac.JPG){: width="800" height="200"}

* 위 IP 정보는 DHCP 서버의 IP 정보이며, DHCP 서버는 현재 "컨트롤러 노드" 에서
  실행 중이다.
* 192.168.207.2 는 DHCP 서버에게 할당 되었으며, MAC 주소는 fa:16:3e:bb:5b:ce 이다.

3.) VM 내부에서 arp 하였다.

![route](/images/arp.JPG){: width="800" height="200"}

* 문제가 바로 보인다.
* VM 내부에서는 192.168.207.2 의 MAC 주소를 94-3f-c2-55-5e-fc 로 알고있다.
* 2.) 에서 보듯이 DHCP 서버의 MAC 주소는 fa:16:3e:bb:5b:ce 이다.
* 즉, 192.168.207.2 IP를 두개의 디바이스에서 서로 가지고 있다. (충돌 문제다.)


결론
----

* 메타데이터 서비스를 호출하려면 DHCP 서버(192.168.207.2)를 게이트웨이로 거쳐가야 한다.
* 그러나, VM 내부에서는 i92.168.207.2 IP를 arp 해보면 DHCP 서버가 아닌 다른
  MAC으로 알고있다.
* 그래서 메타데이터 서비스 요청이 다른 장비로 보내지게 되고, 해당 장비는
  메타데이터 서버를 모르니 패킷이 딴데로 증발한다.
* 결론은 IP 충돌이고, DHCP 서버의 IP를 다른 IP 로 변경해야 한다.



> ps - 192.168.207.2 IP는 물리적 스위치에 할당한 IP 라고 한다. 충돌난게 맞다.


검증
------

검증을 위해 우선 아래와 같이 설정을 진행했다. (진행 과정 생략)
* DHCP IP Pool 을 2 ~ 254 가 아닌 20 ~ 254 로 변경했다.
* DHCP Agent 를 재시작하여, DHCP 서버가 `20번 IP` 를 할당 받도록 했다.


검증을 위해 DHCP 서버의 IP를 `20번` 으로 변경했다.

![route](/images/new_dhcp-mac.JPG){: width="800" height="200"}

* MAC 주소는 fa:16:3e:08:fd:e2 이다.


VM 내부에서 라우팅 테이블을 확인했다.

![route](/images/new_route.JPG){: width="800" height="400"}

* 위와 같이 `메타데이터 ( 169.254.169.254 )` 로 가는 패킷은 `게이트웨이 ( 192.168.207.20 )` 을 거쳐 가도록 변경되었다.


VM 내부에서 arp 해보았다.

![route](/images/new_arp.JPG){: width="800" height="200"}

* 게이트웨이 ( 192.168.207.20 ) 의 MAC 주소가 fa-16-3e-08-fd-e2 이다.
* 실제 DHCP 서버의 MAC 주소와 동일한 것으로 확인되었다.



이제 메타데이터 서비스 요청해보자.

![route](/images/curl.JPG){: width="800" height="100"}

* 200 OK !


추가 실험
-----------

* Testbed 에서 VM 100대를 동시에 스케줄링하여 만들었다.
* 모두 메타데이터 서비스를 잘 호출한다.


결론
-----

* 메타데이터 서비스가 불안정 했던 원인은 IP 충돌이다.
* 오픈스택에서 네트워크를 만들 때 DHCP IP Range 를 잘 설정하자.
* 만약 IP Pool 이, 2 ~ 254 라면 20 ~ 254 정도로 변경하자..
* 네트워크 엔지니어에게 사용하지 말아야할 IP 를 물어보는게 정확한 방법이다.

