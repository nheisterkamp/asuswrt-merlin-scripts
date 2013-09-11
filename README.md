asuswrt-merlin-scripts
======================
Some scripts to make setting up some of the more advanced features a lot less time consuming.

For use with the alternative firmware https://github.com/RMerl/asuswrt-merlin.

Only tested with an Asus RT-AC66U.

More scripts will be added in the future.

Mandatory disclaimer
--------------------
These scripts /could/ are provided as-is and are a work in progress. I would love to hear feedback, but please don't 
expect a one-click-and-everything-works solution -- yet. If you have any custom scripts/configs in /jffs be sure to back 
them up. The scripts are designed to only be invasive in netatalk and avahi configs, but I can't oversee any unintended
side-effects for the moment.

That being said, my computer recognizes the router as a Time Machine. With the added benefit of being able to run some 
more custom software on the device.

YMMV.


Time Machine
------------
The reason to start with this project is to provide an easy way to add Mac OS X's Time Machine capabilities to this 
fine router.

###Usage
```
sh timemachine.sh [user [password]]
```

If your username contains spaces and you are passing it along using a command-line argument, please enclose it in 
quotes "".

### Prerequisites
1. Install asuswrt-merlin on your router;
2. Connect a USB-drive with at least one partition formatted in ext3;
3. Enable JFFS (although the script can do this for you, but it will need to reboot);
4. Install Entware (if you don't have it installed, the script will launch the setup for you).

### Installation
You have a few options here, just pick the one you enjoy most:

* Enable an SSH connection to your router via the Web Interface.

  Log in with your favorite SSH client and run:
  ```
  # wget -c http://rawgithub.com/nheisterkamp/asuswrt-merlin-scripts/master/timemachine.sh -P /tmp
  # sh /tmp/timemachine.sh
  ```
  Or as a one-liner:
  ```
  wget -c http://rawgithub.com/nheisterkamp/asuswrt-merlin-scripts/master/timemachine.sh -P /tmp && sh /tmp/timemachine.sh
  ```
* Or clone everything and run this in your Linux/Mac command-line:
  ```
  # chmod +x runonrouter.sh
  # sh runonrouter.sh <user>@<router.ip> timemachine.sh [user [password]]
  ```
* Put it on a USB drive and execute it using SSH on the router.
* Run the one-liner through the web interface, although this will probably cause some problems at this time.


And just follow the instructions given by the script.

### Finally
Just log in on your router using Finder, or enable Time Machine in System Preferences. Enjoy.
