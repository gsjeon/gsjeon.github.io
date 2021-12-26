22 년도를 위한 블로그 이전
==========================



.. author:: 전광석
.. categories:: blog
.. tags:: blog, christmas
.. comments::

22 년도 부터 기술 블로그를 이전한다.

크리스마스를 맞아 새로운 블로그를 개설하자!

   Merry, christmas!


.. more::

블로그 플랫폼 선택
------------------

플로그 플랫픔은 매우 다양하다.

* 네이버 블로그
* 카카오 티스토리
* 구글 블로그
* 깃허브 페이지
* 워드프레스
* 미디엄
* 노션 
* 등등…..
 
내가 원하는 블로그는 뭘까?

* 무료로 사용했으면 한다. (광고수익 필요없다.)
* Command 나 Source Code 표현이 되어야 한다.
* 검색, 카테고리, 태그, 아카이브, 댓글

위와 같이 내가 원하는 기능들은 거의 모든 플랫폼에서 지원한다.

그래서 익숙하게 사용되는 GitHub 기반의 호스팅인 ``GitHub Pages`` 를 사용하기로 했다.

GitHub Pages 는 보통 `jekyll <https://jekyllrb-ko.github.io/>`_ 이 많이 사용된다. (Ruby 기반임)

예전에 써봤는데, 개인적인 생각으로 뭔가 불편해서 안썻었다.. 

그래서 `Tinkerer <https://vladris.com/tinkerer/>`_ 를 사용하여 ``Github Pages`` 에 호스팅하기로 선택했다.

이전 회사에서 ``tinkerer`` 를 사용해본 경험이 있기 때문에 친숙하고,

개인적으로 ``markdown`` 보다 ``rst (reStructuredText)`` 를 좋아하고, 
``Ruby`` 보다 ``Python`` 을 좋아하기 때문이다.

Tinkerer ?
----------

`Tinkerer <https://vladris.com/tinkerer/>`_ 는 ``Python`` 기반의 
``SSG (Static Site Generator)`` 이다.

`Sphinx <https://www.sphinx-doc.org/en/master/>`_ 로 구동되며 ``Sphinx`` 의 확장 프로그램으로 보면 된다.

`rst (reStructuredText) <https://en.wikipedia.org/wiki/ReStructuredText>`_ 문법으로 글을 작성해야 한다.

`Tinkerer GitHub <https://github.com/vladris/tinkerer/>`_ 에 가보니 활발히 개발되진 않고,
마지막 commit 이 2년전이다.

그럼에도 불구하고 이걸 사용하려는 이유는 개인적으로 너무 좋고 편하다.

만약 사용하다 문제가 있다면 내가 고쳐서 컨트리뷰트할 생각이다.

그래서 내 저장소로 fork 했다. 

Tinkerer 이미지 제작
--------------------

현 최신 버전의 Tinkerer 는 ``Python 3.6`` 을 지원한다.

현재 내 랩탑에는 ``Python 3.8`` 가 설치되어 있기 때문에 사용하는데 문제가 있을 수 있다.

나중에 ``Python 3.8`` 을 지원하도록 고쳐서 ``컨트리뷰트`` 할 생각이다.

결론은 지금은 Tinkerer 를 사용할 ``Python 3.6`` 환경이 필요하다.

그래서 ``Pyhton 3.6`` + ``Tinkerer`` 를 설치한 컨테이너 이미지를 제작하려고 한다.

Blog Posting 환경이내 랩탑에 의존하지 않도록 컨테이너 이미지로 만들어 freeze 하자.

왜냐면 랩탑 고장이나 혹은 다른 PC 에서도 자유롭게 Posting 을 하기 위함이다.

 

Dockerfile::

   $ cat Dockerfile 
   FROM        python:3.6.15-slim-buster

   # Install tinkerer version 1.7.2 (current latest version)
   WORKDIR     /tinker
   RUN         apt update \
               && apt install -y git vim \
               && pip install tinkerer==1.7.2
    

Build::

   $ docker build -t gsjeon/tinkerer:1.7.2 .
 

Push::

   $ docker push gsjeon/tinkerer:1.7.2

* 내 개인 공개 `DockerHub <https://hub.docker.com/repository/docker/gsjeon/tinkerer>`_ 에 올려두었다.

Tinkerer 사용법
---------------

위에서 Tinkerer 용 컨테이너 이미지를 만들었다.

Tinker 사용시 컨테이너에 접속하여 사용하는 방법을 설명한다.

우선 Github Pages 를 사용하려면 깃 레포가 필요하니 만든다.

* 만드는 과정 생략

 

로컬 PC 에 Clone 한다.::

   $ git clone https://github.com/gsjeon/gsjeon.github.io.git
 

Tinker 컨테이너 접속.::

   $ cat tinker.sh 
   #!/bin/bash

   docker run --rm \
              -it \
              --volume ${HOME}/gsjeon.github.io:/tinker:rw \
              --volume ~/.gitconfig:/etc/gitconfig:ro \
              --user $(id -u):$(id -g) \
              gsjeon/tinkerer:1.7.2 \
              bash

           
   $ ./tinker.sh 
    
Tinker init.::

   $ tinker --setup

* 최초 1회만 실행

Tinker Post.::

   $ tinker -p 'Hello World'
   New post created as '/tinker/2021/12/25/hello_world.rst'

   $ cat 2021/12/25/hello_world.rst 
   Hello World
   ===========



   .. author:: 전광석
   .. categories:: test
   .. tags:: test, christmas
   .. comments::

   Hello, World!

   .. more::

   Merry, christmas!
    

   Tinker build


   $ tinker -b
    

   Git commit & push


   $ git add --all
   $ git commit -am 'Added New Post'
   $ git push
    

Tinker 컨테이너 종료.::

   $ exit

이제 위와 같이 포스팅할때 tinker.sh 로 접속하여 포스팅 후 exit 로 종료하면서 사용하면 된다.

2022 신나게 포스팅하자!
