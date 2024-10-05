FROM python:3.12-bookworm

RUN mkdir /root/u-boot

COPY . /root/amlogic-boot-fip/

WORKDIR /root/amlogic-boot-fip
