FROM peerlibrary/runit

MAINTAINER Mitar <mitar.docker@tnode.com>

EXPOSE 3000/tcp

COPY ./etc/apt /etc/apt

RUN apt-get update -q -q && \
 apt-get install adduser curl --yes --force-yes && \
 apt-get install -t wheezy-backports git --yes --force-yes && \
 apt-get install libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++ --yes --force-yes && \
 adduser --system --group peerlibrary --home /home/peerlibrary && \
 export PATH=~/.meteor/tools/latest/bin:$PATH && \
 curl --silent http://meteor.peerlibrary.org/ | sh && \
 echo "$PATH" && \
 ls -al ~/.meteor/tools/latest/bin && \
 npm config set unsafe-perm true && \
 npm install -g git+https://github.com/oortcloud/meteorite.git

COPY . /peerlibrary

RUN export PATH=~/.meteor/tools/latest/bin:$PATH && \
 cd /peerlibrary && \
 grep path .gitmodules | awk '{print $3}' | xargs rm -rf && \
 ./prepare.sh && \
 mrt bundle /bundle.tgz && \
 cd / && \
 tar -xzf /bundle.tgz && \
 rm /bundle.tgz && \
 cd /peerlibrary && \
 git describe --always --dirty=+ > /bundle/gitversion && \
 cd / && \
 rm -rf /peerlibrary

COPY ./etc /etc

ENV ROOT_URL http://example.com
ENV MAIL_URL smtp://user:password@mailhost:port/
ENV METEOR_SETTINGS {}
ENV PORT 3000
ENV MONGO_URL mongodb://mongodb/peerlibrary
ENV MONGO_OPLOG_URL mongodb://mongodb/local
