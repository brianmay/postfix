FROM debian:buster
LABEL maintainer="Brian May <brian@linuxpenguins.xyz>"

RUN apt-get update -q --fix-missing && \
  apt-get -y upgrade && \
  apt-get -y install postfix sasl2-bin rsyslog && \
  rm -rf /var/lib/apt/lists/*

EXPOSE 587

COPY . /opt/postfix/

ENTRYPOINT [ "/opt/postfix/start_server.sh" ]
