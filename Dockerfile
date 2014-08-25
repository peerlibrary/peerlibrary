FROM peerlibrary/runit

MAINTAINER Mitar <mitar.docker@tnode.com>

EXPOSE 3000/tcp

COPY . /peerlibrary

RUN curl --silent https://install.meteor.com/ | sh && \
 npm install --silent -g git+https://github.com/oortcloud/meteorite.git && \
 /peerlibrary/prepare.sh

COPY ./etc /etc
