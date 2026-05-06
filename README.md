# Settings collection for Test Bench PC

## Plug-in USB devices

Copy all udev rules into:

`/etc/udev/rules.d`

Like:

`$ sudo cp udev/* /etc/udev/rules.d/`

You should be root.

Reload confings with udavadm command:

`$ sudo udevadm control --reload-rules && udevadm trigger`

Before to do this check if all usb devices are unpluged.
