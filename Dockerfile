FROM debian:buster
LABEL maintainer="Brian May <brian@linuxpenguins.xyz>"

RUN apt-get update -q --fix-missing && \
  apt-get -y upgrade && \
  apt-get -y install postfix sasl2-bin rsyslog && \
  rm -rf /var/lib/apt/lists/*

EXPOSE 25
EXPOSE 587

COPY . /opt/postfix/

# Setup access to version information                                            
ARG VERSION=
ARG BUILD_DATE=
ARG VCS_REF=
ENV VERSION=${VERSION}
ENV BUILD_DATE=${BUILD_DATE}
ENV VCS_REF=${VCS_REF}

ENTRYPOINT [ "/opt/postfix/start_server.sh" ]
