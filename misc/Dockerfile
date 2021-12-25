FROM        python:3.6.15-slim-buster

# Install tinkerer version 1.7.2 (current latest version)
WORKDIR     /tinker
RUN         apt update \
            && apt install -y git vim \
            && pip install tinkerer==1.7.2
