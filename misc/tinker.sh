#!/bin/bash

docker run --rm \
           -it \
	   --volume ${HOME}/gsjeon.github.io:/tinker:rw \
	   --volume ~/.gitconfig:/etc/gitconfig:ro \
	   --user $(id -u):$(id -g) \
	   gsjeon/tinkerer:1.7.2 \
	   bash
