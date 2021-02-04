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

VM 을 만들면, VM은 메타데이터 서비스 호출을 위해 아래와 같이 라우팅 테이블이
셋팅된다.


![route](/images/route.JPG =800x400)
