FROM tozd/runit

EXPOSE 3000/tcp

VOLUME /var/log/meteor

ENV HOME /

RUN apt-get update -q -q && \
 apt-get --yes --force-yes install curl git libcairo2-dev libfreetype6-dev libjpeg8-dev libpango1.0-dev libgif-dev build-essential g++ && \
 curl http://meteor.peerlibrary.org/ | sed s/--progress-bar/-sL/g | sh && \
 export PATH=$HOME/.meteor/tools/latest/bin:$PATH && \
 npm config set unsafe-perm true && \
 npm install -g git+https://github.com/oortcloud/meteorite.git

COPY ./etc /etc

COPY . /source

RUN export PATH=$HOME/.meteor/tools/latest/bin:$PATH && \
 cp -a /source /build && \
 rm -rf /source && \
 cd /build && \
 rm -rf etc && \
 grep path .gitmodules | awk '{print $3}' | xargs rm -rf && \
 ./prepare.sh && \
 mrt bundle /bundle.tgz && \
 cd / && \
 tar xf /bundle.tgz && \
 rm /bundle.tgz && \
 cd /build && \
 git describe --always --dirty=+ > /bundle/gitversion && \
 cd / && \
 rm -rf /build && \
 adduser --system --group meteor --home /

ENV ROOT_URL http://example.com
ENV MAIL_URL smtp://user:password@mailhost:port/
ENV METEOR_SETTINGS {}
ENV PORT 3000
ENV MONGO_URL mongodb://mongodb/meteor
ENV MONGO_OPLOG_URL mongodb://mongodb/local
