#!/bin/bash

sudo cp udev/* /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
