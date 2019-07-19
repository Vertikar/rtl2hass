#
# Docker file to create an image that contains enough software to listen to events on the 433,92 Mhz band,
# filter these and publish them to a MQTT broker.
#
# The script resides in a volume and should be modified to meet your needs.
#
# The example script filters information from weather stations and publishes the information to topics that
# Domoticz listens on.
#
# Special attention is required to allow the container to access the USB device that is plugged into the host.
# The container needs priviliged access to /dev/bus/usb on the host.
# 
# docker run --name rtl_433 -d -e MQTT_HOST=<mqtt-broker.example.com>   --privileged -v /dev/bus/usb:/dev/bus/usb  <image>

FROM balenalib/rpi-raspbian

LABEL Description="This image is used to start a script that will monitor for events on 433,92 Mhz" Vendor="MarCoach" Version="1.0"
LABEL Maintainer="Jordan Ochocki"

#
# First install software packages needed to compile rtl_433 and to publish MQTT events
#
RUN apt-get update && apt-get install -y \
  rtl-sdr \
  librtlsdr-dev \
  librtlsdr0 \
  git \
  automake \
  make \
  libtool \
  cmake \
  jq \
  python \
  python-pip \
  python-setuptools

#
# Install Paho-MQTT client
#
RUN pip install wheel
RUN pip install paho-mqtt

#
# Blacklist kernel modules for RTL devices
#

RUN echo 'blacklist rtl2832 \
blacklist r820t \
blacklist rtl12830 \
blacklist dvb_usb_rtl128xxu' \
> /etc/modprobe.d/rtl.blacklist.conf

#
# Pull RTL_433 source code from GIT, compile it and install it
#
RUN git clone https://github.com/merbanan/rtl_433.git \
  && cd rtl_433/ \
  && mkdir build \
  && cd build \
  && cmake ../ \
  && make \
  && make install 

#
# Define an environment variable
# 
# Use this variable when creating a container to specify the MQTT broker host.
ENV MQTT_HOST
ENV MQTT_PORT 1883
ENV MQTT_TOPIC rtl_433/+/events
ENV DISCOVERY_PREFIX homeassistant
ENV DISCOVERY_INTERVAL 600

#
# Copy my script
#
COPY rtl2mqtt_hass.py /scripts/rtl2mqtt_hass.py

#
# Execute python script
#

CMD [ "python", "/scripts/rtl2mqtt_hass.py" ]