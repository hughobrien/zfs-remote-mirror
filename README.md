ZFS Remote Mirrors for Home Use
===============================
Why pay a nebulous cloud provider to store copies of our boring, but nice to have data? Old photographs, home videos, college papers, MP3s from Napster; let's just stick them somewhere and hope the storage doesn't rot.

We can do better. Magnetic storage is cheap; and our data is valuable. We don't need live synchronisation, cloud scaling, SLAs, NSAs, terms of service, lock-ins, buy-outs, up-sells, shut-downs, DoSs, fail whales, pay-us-or-we'll-deletes, or any of the noise that comes with using someone else's infrastructure. We'd just like a big old drive that we can backup to, reliably, easily, and privately.

How about an automatic, remote, encrypted, verifiable, incremental backup of all your data, for about 100 currency units in outlay, less if you have existing hardware, and no upkeep costs?

* Computer hardware is cheap, an old laptop or a [SoC board](https://en.wikipedia.org/wiki/Single-board_computer) is more than sufficient.
* USB external storage is [laughably inexpensive](http://www.amazon.co.uk/s/keywords=external+hard+drive&ie=UTF8) ([35USD/TB](https://en.wikipedia.org/wiki/List_of_Storage_hierarchy_media_with_costs)).
* Parents/Friends will allow you to keep the system in their homes.
* Enterprise grade [security](https://en.wikipedia.org/wiki/OpenSSH) and [storage](https://en.wikipedia.org/wiki/ZFS) features are available in [free operating systems](https://en.wikipedia.org/wiki/FreeBSD).

You can have:
--------------
* A block level copy of your ZFS pool, replicating all datasets and snapshots.
* Automated incremental backups so that only changed data is transferred.
* Complete at-rest encryption, with the key resident in memory only during backup operations.
* Hardened communication security, so your data is safe in-flight.
* A minimalistic, locked down, low-power remote server requiring almost no maintenance.
* All wrapped up as a single command, powered entirely by tools in the FreeBSD base system.

Alternatively, if you're not currently enjoying the benefits of ZFS, you could take this opportunity to set up a low cost home storage server. You'll need two of each component as described below. If you're anything like me you probably have files scattered across dozens of devices and it's actually quite nice to consolidate them in an easily accessible and safe place.

You will need:
--------------
* A FreeBSD 10.1 (or later) [supported](https://www.freebsd.org/doc/en_US.ISO8859-1/articles/committers-guide/archs.html) system, such as:
 * A [Raspberry Pi](https://en.wikipedia.org/wiki/Raspberry_Pi), [BeagleBoard](https://en.wikipedia.org/wiki/BeagleBoard) or another [FreeBSD ARM target](https://www.freebsd.org/platforms/arm.html), use a 4GB+ SD Card.
 * An old laptop, with around 512MB of memory, preferably something quiet.
* A USB Hard Drive.
 * If using an SoC system, a drive that comes with its own power supply is useful.
 * If using an old laptop, a drive powered directly by USB is probably better.
* An Ethernet Internet connection in a location that is not your home.
 * Do not use Wi-Fi. Frustration abounds.
* The ability to reach the system from the outside world. Potentially via:
 * [Port forwarding](http://portforward.com/) (most likely).
 * IPv6.
 * Overlay routing ([Tor](https://en.wikipedia.org/wiki/Tor_(anonymity_network)), [I2P](https://en.wikipedia.org/wiki/I2P), [cjdns](https://en.wikipedia.org/wiki/Cjdns)).

I'm specifying a laptop as it's a lot more palatable a device to ask someone to let you keep in their home. You can of course use a desktop if you have sufficient charm.

Please note, that ZFS is designed for serious, enterprise grade environments. Using it on older consumer hardware is doing an injustice to its many features, and the kernel will remind you of this on every boot. That said, it can be squeezed into this restricted use case, and you can have many of the benefits most important to a backup system. However, if you can supply more modern hardware, do. A system with ECC memory would be a wise investment also. Even if it is an older model.

If you must go with "previously loved", hardware, do yourself a favour and run a memory test first. Faulty DIMMs are a heartbreak one only tolerates once. [MemTest86+](http://www.memtest.org/) is a good choice, but their ISOs don't work on USB drives, only CDs. You could mess about with *gpart* to create a [bootable partition manually](http://forum.canardpc.com/threads/28875-Linux-HOWTO-Boot-Memtest-on-USB-Drive?p=1396798&viewfull=1#post1396798) but the good folks at Canonical added *memtest* to the bootscreen of some Ubuntu installers, which can be dandily *dd*'d to a memory stick. I can attest to [14.04.2 LTS Server](http://releases.ubuntu.com/trusty/) having this.

**Note:** The current FreeBSD RaspberryPi images do not include the ZFS kernel modules by default. It's possible to [build your own images](https://wiki.freebsd.org/FreeBSD/arm/Raspberry%20Pi) however.
Why not mirror the drives locally?
----------------------------------
**Pros:**
* No remote system needed.
* No network connection needed for backups, therefore much faster.
* ZFS can auto-recover any corruption without missing a beat.

**Cons:**
* Devices are vulnerable to localised physical damage, e.g. fire, dogs, children.
* Filesystems are susceptible to user stupidity as writes are synchronised live (snapshots help).

Why not some another way?
-------------------------
Some alternatives include [rsync](https://en.wikipedia.org/wiki/Rsync), [bup](https://bup.github.io/), [obnam](http://obnam.org/), [git-annex](https://git-annex.branchable.com/), [something else](https://wiki.archlinux.org/index.php/Backup_programs).

**Pros:**
* Easier to setup.
* OS agnostic.
* *Potentially* local only decryption.

**Cons:**
* No ZFS features, such as:
 * Free snapshots.
 * Data integrity verification.
 * Block compression.
 * Deltas based on actual modified blocks, not file modification timestamps.

These solutions focus on backing up individual files, which I believe is a less useful system than a full mirror. They are certainly easier to setup though.

It's worth noting that as we send the decryption key to the remote device, our method is somewhat less secure than a method that never allows the remote system to view plaintext data. If someone has physical access then it's possible for the key to leak through side-channel analysis or system subversion.

The Solaris version of ZFS allows [per-dataset encryption](http://www.oracle.com/technetwork/articles/servers-storage-admin/solaris-zfs-encryption-2242161.html), which allows the pool to synchronise without exposing the plaintext data. This feature hasn't yet made it to FreeBSD, but for data that needs extra protection, we can approximate it (details further on).

Threat Model
------------
Since nothing is really *secure*, just appropriately difficult, it's good to define what threats we'd like to defend against. This way we can spot when we've gone too far, or not far enough.

* Data Loss - Made difficult by the existence of the remote backup and regular synchronisation.
* Data Leaks - Made difficult by the at-rest encryption on the remote disk.
* Server Breach (Digital) - Made difficult by judicious use of SSH keys.
* Server Breach (Physical) - Made difficult by the front door lock of the home.

This list doesn't cover any of the security of our main system of course, only the remote one. Presumably you have some sort of disk encryption in use already.

The physical risk is the hardest to defend against. An attacker with physical access could potentially modify the system to capture the decryption key. Passwords are required for local logins, so the system would have to be shut down to modify it, unless they can exploit a faulty USB stack or similar alternative entry.

To defend against physical threats, you could encrypt the OS drive of the system and require a USB key to boot it, that way if it was ever powered down it could not be surreptitiously modified and rebooted. However, any time it crashes, or suffers a power cut, you'd have to boot it manually, or request your kind host to do so. I feel that this level of defence is more trouble than it's worth. See the section *Extra Encryption* for an easier alternative.

Secret Material
--------------
Any good crypto system is defined by the secrets it requires. For this setup, we need two:

* The password for the master SSH signing key trusted by the backup system.
* The encryption key for the hard disk.

Other secrets like the passwords for the root and the user account are less important. They will also not really be used beyond the initial setup stage, so I recommend choosing one single [strong password](https://xkcd.com/538/) and using it for all three cases. You can generate one like this:

	hugh@local$ echo $(strings /dev/random | sed -E '/^.{6}$/!d;/[[:space:]]|[[:punct:]]/d' | head -n 2 | tr -d '\n')

	brno7aaJKusz

That reads any strings that emerge from the noise of the PRNG, discards any not six characters long, and any containing whitespace or punctuation. After two such strings have been emitted it puts them together and *echo* ensures there's a newline at the end. We could just look for a single twelve character string matching our needs but that takes a while, those monkeys can only type so fast.

For future reference, all the commands I show you are written to run on a FreeBSD system. GNU utilities often take different arguments so you might be able to translate with careful reference to the *man* pages. Also, I'll write the names of system components in *italics*. E.g. ZFS is the product, *zfs* is the command to control it.

Server Setup
============
OS Installation
---------------
Step one, is of course, to install FreeBSD. If this sounds daunting to you, take a look at the excellent [Handbook](https://www.freebsd.org/doc/handbook/). There's different ways to do this based on what platform you're using but here's a run down of some answers to the questions the installer will ask you on an i386/amd64 target. **Do not** connect your USB drive yet.

* Choose *install* from the *Install / Shell / Live CD* dialogue.
* Choose your desired keymap. (I use *UK ISO-8859-1*)
* Name the machine (*knox* is a good name).
* Deselect **all** optional system components (*doc, games, ports, src*)
* Choose *Auto (UFS)* over the *entire disk*. Defaults are usually fine.
* Set your **strong** root password.
* Set up *IPv4* with *DHCP* unless you know better.
* I don't bother with *IPv6* as Irish ISPs haven't heard of it.
* Your clock is usually UTC, so say *yes*.
* Choose your timezone.
* **Disable all** services on boot. We'll configure them manually.
* Do not add users now. We'll do it later.
* Choose *Exit* from the final menu.
* **YES**, you do want to enter a shell to make final modifications.


Congratulations. You are standing in a root shell west of a fresh system, with a boarded network interface. There is a small mailbox here, but we'll soon disable it.

Before we continue, a word about FreeBSD partitions. Old wisdom was to split out */usr*, */var* and sometimes other aspects of the directory hierarchy onto different partitions. This has a few benefits, the most obvious is that some branches, especially */var* tend to grow with system logs and other detritus. If these were allowed to grow unchecked, they might consume the entire disk which brings out edge-case complications Splitting them off mitigates this, but with the system's specialised usage such growth isn't likely to be a problem, and it's nothing a quick check can't solve.

There was another argument to be made for performance; different branches have different read/write profiles, and splitting them reduced fragmentation for the read-mostlies. This is still true, but not significant on flash media due to uniform seek times and not worth the hassle on a dedicated system like this. More than a moment's system tuning is for high-performance servers, and if we were interested in that we wouldn't be using old hardware. Let's keep it simple.

Finally, swap space used to be best placed at the edge of the platter (the last sectors) as the most sectors pass per rotation there. This reason goes out the window with flash, but it's still a good idea to put the swap at the end, it makes it easier to grow the partitions if we ever migrate to a larger card.

Thankfully, the FreeBSD installer will choose all of the above tweaks by default if you use guided mode.

Users
-----
The hash/pound/[octothorpe](https://en.wiktionary.org/wiki/octothorpe) symbol (*#*) at the start of a prompt indicates *root* permissions. When I use it in-line as below it's a comment that you should read but not type in. Some config files will treat it as a comment, others, like SSH, will treat it as an error.

	# adduser

	Username: hugh # you can use your own name if you want
	Full name: <enter>
	Uid (Leave empty for default): <enter>
	Login group [hugh]: <enter>
	Login group is hugh. Invite hugh into other groups? []: wheel # this grants su access
	Login class [default]: <enter>
	Shell (sh csh tcsh nologin) [sh]: tcsh
	Home directory [/home/hugh]: <enter>
	Home directory permissions (Leave empty for default): <enter>
	Use password-based authentication? [yes]: <enter>
	Use an empty password? (yes/no) [no]: <enter>
	Use a random password? (yes/no) [no]: <enter>
	Enter password: <use the root password>
	Enter password again: <reboot the system. No, I kid.>
	Lock out the account after creation? [no]: <enter>
	...
	...
	OK? (yes/no): yes
	adduser: INFO: Successfully added (hugh) to the user database.
	Add another user? (yes/no): no
	Goodbye!

Yes, it's really that chatty, but look at [*man pw*](https://www.freebsd.org/cgi/man.cgi?pw(8)) to see what the alternative is. If you're wondering about the term *wheel* [here's an explanation](https://unix.stackexchange.com/questions/1262/where-did-the-wheel-group-get-its-name).

Connecting
----------
Now we need to discover what IP address the DHCP server leased to the system. Ignore *lo0* as it's the loopback interface. Also note the interface name, *bfe0* in this case.

	# ifconfig

	bfe0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
		options=80008<VLAN_MTU,LINKSTATE>
		ether 00:15:c5:00:00:00
		inet 192.168.1.23 netmask 0xffffff00 broadcast 192.168.1.255
		nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
		media: Ethernet autoselect (100baseTX <full-duplex>)
		status: active

With this in hand we can SSH into the machine; *sshd* will generate some host keys automatically at this point, but before we let that happen, let's shake that odd feeling we both have that there hasn't been enough entropy in this baby-faced system yet to yield secure random numbers.

	# dd if=/dev/random of=/dev/null bs=1M count=512

Now we haven't really added entropy of course, but at least we're far enough down the PRNG stream to be hard to predict.

Start OpenSSH. Note that this is being started in a *chroot* environment, so when we come to *ssh* in, we'll find ourselves within that same environment.

	# service sshd onestart

Before we connect, we should first setup our **local** SSH configuration.

	hugh@local$ mkdir ~/.ssh
	hugh@local$ chmod 700 ~/.ssh
	hugh@local$ touch ~/.ssh/config
	hugh@local$ chmod 600 ~/.ssh/config

Edit your **local** *~/.ssh/config* and insert the following:

	HashKnownHosts yes

	Host knox
		User hugh
		HostName 192.168.1.23 # We'll swap in the FQDN later
		HostKeyAlgorithms ssh-ed25519

Now we can simply use:

	hugh@local$ ssh knox

There'll be a prompt to accept the host key as it's the first time *ssh* has seen it. If you think you are currently the victim of a LAN scale MitM attack you can compare the displayed key to the one on the new system before accepting. You may also want to switch to a low-sodium diet.

	# ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

Now that we're in, we can use the copy/paste features of our terminal to make the config file editing a little more palatable.

/etc/rc.conf
------------

Use *su* to get a root shell.

	hugh@knox$ su
	root@knox#

We'll be editing several config files so I hope you know your *vi* keybindings. If not, there's *ee*, which feels like a tricycle after *vi*, but I digress. **Replace** */etc/rc.conf* with the following. You'll have to supply your own network adapter name gleaned from *ifconfig*.

	hostname="knox"
	keymap="uk.iso.kbd" # delete this line for US keyboard layout
	ifconfig_bfe0="DHCP" # the equivalent of this line may already be present
	sshd_enable="YES"
	ntpd_enable="YES" # keep the system regular
	ntpd_sync_on_start="YES"
	powerd_enable="YES" # keep power usage down
	sendmail_enable="NO" # no need for sendmail
	sendmail_submit_enable="NO"
	sendmail_outbound_enable="NO"
	sendmail_msp_queue_enable="NO"
	dumpdev="NO" # defaults to no on RELEASE but you may be on CURRENT

Let's have *ntpd* synchronise the clock before we proceed:

	root@knox# service ntpd start

/etc/crontab
------------

*cron* is the system command scheduler. *cron* really likes to send email, but since we've disabled *sendmail* this email will all pile up in */var/spool*. Add the following line to the top of */etc/crontab* to muzzle it.

	MAILTO=""

/etc/fstab
---------
This is the file system tab, which used to be a listing of all the filesystems the kernel should mount at boot time, but is fading a little in importance these days with removable devices and ZFS. It's not obsolete yet though. Here's the contents of mine, note that the fields are separated by tabs, which is why that zero looks so lonesome.

	# Device        Mountpoint      FStype  Options Dump    Pass#
	/dev/ada0p2     /               ufs     rw      1       1
	/dev/ada0p3.eli none            swap    sw      0       0
	tmpfs           /tmp            tmpfs   rw,mode=1777    0       0
	tmpfs           /var/run        tmpfs   rw      0       0
	tmpfs           /var/log        tmpfs   rw      0       0


Your partition names may be different. I've enabled encrypted swap by appending the *.eli* suffix onto the device name of the swap partition. This ensures that no potentially sensitive memory is ever written out to disk in the clear. I've also added three *tmpfs* mounts; these are memory disks and are therefore cleared on reboot. By turning the */var/log* directory into a memory disk, we should be able to keep the main system drive spun down most of the time, reducing power and extending its life. Of course, this doesn't really matter on flash devices. The other two are really just used for storing tiny files that should be cleared between boots anyway, so it makes sense to hold them in memory.

Be aware the using encrypted swap will prevent you from gathering automated crash dumps. This isn't a problem if your system isn't crashing, but if it starts to, switch back to regular swap (remove the *.eli* extension) and set *dumpdev="AUTO"* in */etc/rc.conf*. Then, after a panic, you can run *kgdb* against the kernel and the dump to isolate what function caused the issue. Hopefully you can forget this paragraph exists though.

/etc/ttys
---------
TTY stands for *teletypewriter*, which is an early method for interacting with systems of the UNIX era. This file controls the allocation of virtual TTYs. Here's my copy, you'll note that it's a lot smaller than the system default. Tabs are in use again.

	console none                            unknown off insecure
	ttyv1   "/usr/libexec/getty Pc"         xterm   on  secure

This disables all but one of the virtual consoles, leaving ttyv1, not v0 as the enabled one. This helps prevent the terrible temptation to login to ttyv0 and curse as various system messages overprint your session. The insecure option for *console* forces single user mode to require a password, which won't stop a serious physical attacker, but may deter a too-curious teenager.

/boot/loader.conf
-----------------
I like this one, it controls the environment the kernel loads into. It's a mix of some power control options and ZFS tuning parameters that should improve performance and stability on low memory systems. ZFS is very fond of memory, and runs in the kernel address space, so by limiting it we avoid some nasty memory conditions. The values here are for a 512MB system, if you have more memory than that you might consider increasing them after researching what they do, but they'll work for now. You should probably omit the two *hint* lines on SoC systems, though they're likely harmless.

Note that this file isn't present by default.

	autoboot_delay=3 # speed up booting
	hint.p4tcc.0.disabled=1 # use only modern CPU throttling (x86 only)
	hint.acpi_throttle.0.disabled=1 # does your SoC use ACPI? RPi doesn't.
	zfs_load="YES"
	geom_eli_load="YES"
	vm.kmem_size="150M" # limit the kernel's memory usage
	vm.kmem_size_max="150M"
	vfs.zfs.arc_max="32M" # limit the ZFS cache size
	vfs.zfs.vdev.cache.size="16M" # limit per-device cache

/etc/sshd/sshd_config
---------------------
We're back to SSH now, and this is where I think things get really interesting. We're going to be using SSH's certificate authority features to authorise different keys. This means we give the system one key to love, honour, and obey, and then anything we sign with that key will work even if the system hasn't seen it before. Naturally, the CA key itself then should be protected with a password as good as the *root* password as it will essentially be another way of getting *root* access. Personally I think you should re-use the existing *root* password here but you may feel otherwise.

Accept the default path for the key when prompted. We'll also want to copy the key over to our main machine without using *root* so copy it to the user's home directory.

	root@knox# ssh-keygen -t ed25519
	root@knox# cp /root/.ssh/id_ed25519 /usr/home/hugh/knox-ca
	root@knox# chown hugh /usr/home/hugh/knox-ca

Let's grab that key before we tweak *sshd*:

	hugh@local$ scp knox:knox-ca ~/.ssh/

Now, **replace** the contents of */etc/ssh/sshd_config* with the following (the whole thing). This avoids crypto suspected to be [NSA/FVEYS vulnerable](http://www.spiegel.de/media/media-35515.pdf). Be aware that this machine will now only be contactable by recent versions of OpenSSH, which if you're running a recent OS will be fine.

	HostKey /etc/ssh/ssh_host_ed25519_key
	TrustedUserCAKeys /root/.ssh/id_ed25519.pub
	AllowUsers root hugh
	PasswordAuthentication no
	PermitRootLogin forced-commands-only
	UseDNS no
	UsePAM no
	ChallengeResponseAuthentication no
	KexAlgorithms curve25519-sha256@libssh.org
	Ciphers chacha20-poly1305@openssh.com

Then:

	# service sshd restart
	# rm /usr/home/hugh/knox-ca

SSH Client
----------
Now we'll generate a user identity and sign it with the CA key, and we'll do it properly by using *ssh-agent*. This allows us the security of having password protected keys without the hassle of entering the password every time. We unlock the key once, add it to the agent, and it's available until we logout. *ssh-agent* operates as a wrapper around a shell so firstly we have to work out what shell you're using.

	hugh@local$ ssh-agent $(grep $(whoami) /etc/passwd | cut -d ':' -f 7)

You can avoid that junk if you already know what shell you're using, *echo $0* or *echo $SHELL* can sometimes also contain the shell name, but not too reliably.

Now we're in a sub-shell of the *ssh-agent* process, time to generate the new ID. You should use a password here, possibly the same password as you use to login to your local system, as this key will grant access to the user account on the remote system.

	hugh@local$ ssh-keygen -t ed25519 -f ~/.ssh/knox-shell

Sign the key. The *-I* flag is just a comment.

	hugh@local$ ssh-keygen -s ~/.ssh/knox-ca -I knox-shell -n hugh ~/.ssh/knox-shell.pub

Now we tell *ssh* to use this key when connecting to *knox*. We can add some fancyness while we're at it. Edit your *~/.ssh/config*:

	HashKnownHosts yes
	ControlMaster auto
	ControlPath /tmp/ssh_mux_%h_%p_%r
	ControlPersist 30m

	Host knox
		User hugh
		HostName 192.168.1.23 # We'll swap in the FQDN later
		HostKeyAlgorithms ssh-ed25519
		IdentityFile ~/.ssh/knox-shell

The *Control* settings allow us to reuse connections which greatly speeds things up. Now that the key has its bona fides (the *knox-shell-cert.pub* file), we should unlock it and use it to login.

	hugh@local$ ssh-add ~/.ssh/knox-shell
	hugh@local$ ssh knox

If you get dropped into your shell without being asked for a password then all is well. For fun, let's log out and in again to see how snappy the persisted connection makes things:

	hugh@knox$ exit
	hugh@local$ ssh knox
	hugh@knox$ exit

Splendid.

Updates
-------
FreeBSD provides binary updates for [Tier 1 architectures](https://www.freebsd.org/doc/en_US.ISO8859-1/articles/committers-guide/archs.html), i.e. i386 and amd64. You can check your architecture with *uname -p*. If you're not using one of those, (the RPi is ARMv6) you'll have to find [alternative](https://www.freebsd.org/doc/handbook/updating-upgrading.html) ways of keeping the system up to date (flashing a new image or doing a local buildworld). The system is pretty locked down though, so having it always have the latest software isn't really necessary. You can probably ignore this section for now.

Tier 1 users should execute the following, they may take a few minutes to run. *fetch* will present a long list of files that will be updated, you can simply press '*q*' to exit this.

	root@knox# freebsd-update fetch
	root@knox# freebsd-update install


The pkg system
-----------------------
*pkg*, too is tier 1 only, so look to the venerable [ports collection](https://www.freebsd.org/doc/handbook/ports-using.html) for package installations. I've heard tell of some [third party](https://forums.freebsd.org/threads/raspberry-pi-package-repository.48179/) pkg [repositories](https://www.raspberrypi.org/forums/viewtopic.php?f=85&t=30148). Though it usually better to build your own through *ports*, either locally or [on another system](https://www.freebsd.org/doc/handbook/ports-poudriere.html). If you don't feel you need any packages, then you can ignore this.

The blessed ones can run the following; you'll be prompted to install *pkg*.

	root@knox# pkg update

Install [any other packages](https://www.freebsd.org/doc/handbook/ports-finding-applications.html) you like at this point.

At this point we can reboot the system.

	root@knox# sync; reboot

Log in again when it's back and read through the boot messages to see all went well. '+G' tells *less* to start at the end of the file.

	hugh@local$ ssh knox
	hugh@knox$ less +G /var/log/messages

You may, for instance, see:

	Aug  2 00:53:21 knox root: /etc/rc: WARNING: failed to start powerd

Which tells us that for whatever reason, *powerd* isn't able to function on this machine. SoCs may show this, as will VMs. If you see it, remove the *powerd* line from */etc/rc.conf*

Be aware, that if you want to login to the machine physically, instead of via SSH, you must switch to the second console with \<Alt-F2\>. \<Alt-F1\> will return you to the kernel messages screen.

Disk Setup
=========
GELI
----
Time to plug in the USB drive. Let's find out what *knox* is calling it.

	root@knox# camcontrol devlist

	<FUJITSU MHY2160BH 0081000D>       at scbus0 target 0 lun 0 (ada0,pass0)
	<TSSTcorp DVD+-RW TS-L632D DE03>   at scbus4 target 0 lun 0 (pass1,cd0)
	<WD My Passport 0820 1007>         at scbus5 target 0 lun 0 (da0,pass2)
	<WD SES Device 1007>               at scbus5 target 0 lun 1 (ses0,pass4)

The first entry, *ada0* is *knox*'s internal hard drive, the second entry is the laptop's disc drive. The 2TB USB drive sits on *da0* with a monitoring interface we can disregard on *ses0*. Yours will likely be *da0* too.

We should also work out what sector size the drive is using, though in all likelihood we're going to use 4KiB sectors anyway. Most large (2TiB+) drives will be using the [4KiB standard](https://en.wikipedia.org/wiki/Advanced_Format).

	root@knox# camcontrol identify da0 | grep size

	sector size logical 512, physical 4096, offset 0

Yup, it's a 4KiB drive. Now we'll generate the encryption key for the [GELI](https://www.freebsd.org/cgi/man.cgi?geli(8)) full disk encryption (**locally**).

	hugh@local$ dd if=/dev/random bs=1K count=1 > ~/.ssh/knox-geli-key
	hugh@local$ chmod 600 ~/.ssh/knox-geli-key

Strictly, we shouldn't store that in **~/.ssh**, but it's as good a place as any. You'll have noticed that we're not using any password with this key, and since we can't back it up to the backup system (egg, chicken, etc.) we'll need to store it somewhere else. But while we might be happy to have it lying around unencrypted on our local system, where we can reasonably control physical access, we're better off encrypting it for storage on Dropbox or in an email to yourself or wherever makes sense as we don't know who might have access to those systems (presume everyone). You could also stick it on an old USB flash drive and put it in your sock drawer if you know what an [NSL](https://en.wikipedia.org/wiki/National_security_letter) is.

	hugh@local$ cd; tar -cf - .ssh | xz | openssl aes-128-cbc > key-backup.txz.aes

Make sure you use a good password (maybe the same as you use for your login) and stick that *.aes* file somewhere safe (it also contains your SSH identity). Should you ever need to decrypt that file:

	hugh@local$ < key-backup.txz.aes openssl aes-128-cbc -d | tar -xf -
	hugh@local$ ls .ssh

(*tar* can automatically decompress). Let's get a quick measurement on the drive's normal speed before we activate the encryption.

	root@knox# dd if=/dev/zero of=/dev/da0 bs=1M count=100
	..
	104857600 bytes transferred in 15.057181 secs (6963960 bytes/sec)

Send the key over to *knox*, this is only for the initial setup, it won't hold a copy of it. Also, since */tmp* is now a memory drive, we don't need to worry about any hardcore [Guttmann](https://en.wikipedia.org/wiki/Gutmann_method) secure erasure.

	hugh@local$ scp ~/.ssh/knox-geli-key knox:/tmp

The following command creates an AES-XTS block device with a 128 bit key. Other ciphers/lengths are available but the defaults are [pretty good](https://www.schneier.com/blog/archives/2009/07/another_new_aes.html). I feel we can skip *geli*'s integrity options as ZFS is going to handle any cases of incidental corruption and malicious corruption isn't really in our threat model.

	root@knox# geli init -s 4096 -PK /tmp/knox-geli-key /dev/da0
	root@knox# geli attach -dpk /tmp/knox-geli-key /dev/da0

The other *geli* option of note is the sector size. By forcing *geli* to use 4KiB sectors, and only writing to the *geli* overlay, we get the best performance from our drive. Though, given the low power nature of this system, we're unlikely to ever see the benefit due to slower links in the rest of the chain. Since *geli* encrypts per-sector, specifying a larger size also reduces it's workload versus the default 512 byte sectors.

Let's see how this encryption has affected our drive's speed:

	root@knox# dd if=/dev/zero of=/dev/da0.eli bs=1M count=100
	..
	104857600 bytes transferred in 17.759175 secs (5904418 bytes/sec)

	root@knox# echo "5904418 / 6963960" | bc -l

	.84785352012360783232

Fifteen percent drop? Not too bad. Again, this was never going to be a high-performance system.

ZFS
---
Now that we have an encrypted substrate, we can hand it over to ZFS. The *zpool* command handles all things low-level in ZFS. I'm calling my pool *wd* (it's a [WD](https://en.wikipedia.org/wiki/Western_Digital) disk).

	root@knox# zpool create -O atime=off -O compression=lz4 wd da0.eli

Note that I specified the block device as *da0.eli* which is the overlay device exposed by *geli*. *atime* is access time, which logs when a file is accessed. We don't need this, and it hurts performance a little, so out it goes. *lz4* compression is extremely fast, to the point of being almost computationally free, and will let our already large drive go even further. Individual ZFS datasets can override these options later on but they make good defaults. I also have these options set on my local pool, but if your local pool differs then they will be overwritten when we send the filesystem.

ZFS is all setup now (wasn't that easy? No partitioning or anything). Let's see what we have:

	root@knox# zpool status

	  pool: wd
	 state: ONLINE
	  scan: none requested
	config:
			NAME        STATE     READ WRITE CKSUM
			wd          ONLINE       0     0     0
			  da0.eli   ONLINE       0     0     0

	errors: No known data errors

Wonderful, now we tear it all down.

	root@knox# zpool export wd
	root@knox# rm -P /tmp/knox-geli-key

I securely erased the key anyway...couldn't help myself. Since we told *geli* to auto-detach on last close, the *zpool export* is enough to shut down encrypted access. We don't need to explicitly call *geli detach*. We can verify this with:

	root@knox# geli list

You should only see references to the encrypted swap, probably on *ada0p3.eli*. No *da0.eli* in sight. What does *eli* stand for anyway? I haven't been able to [figure that out](https://forums.freebsd.org/threads/what-does-geli-stand-for-not-what-does-it-do.42546/).

Datasets
--------
ZFS datasets allow you to specify different attributes on different sets of data; whether to use compression, access control lists, quotas, etc. I find that I need precisely none of those features, preferring to treat my backup storage as one large dataset with sane properties. There's nothing stopping you from creating different datasets and synchronising them to the backup system, I just don't see the point for personal backups. Know also that it makes previewing the differences between snapshot more complex, as *diff* cannot automatically recurse into dependent snapshots, it has to be done per dataset. This isn't a big deal though.

Plumbing
========
Drop the following script into *root*'s home directory, call it *zfs-receive.sh*. I would have preferred to invoke these commands remotely but after a lot of experimenting, triggering the script remotely was the only way I found that properly detached the encrypted drive in the event of connection failure. So rest assured, you're protected against that.

	#!/bin/sh

	geli attach -dpk /tmp/k /dev/da0
	zpool import wd
	zfs receive -Fdu wd
	zpool export wd

Then:

	root@knox# chmod 700 /root/zfs-receive.sh

What's this you say? I promised that we wouldn't store the key on the backup server? [Behold!](https://en.wikipedia.org/wiki/Named_pipe)

Don't set any passwords on these two keys, we need them to be scriptable.

	hugh@local$ ssh-keygen -t ed25519 -f ~/.ssh/knox-fifo
	hugh@local$ ssh-keygen -t ed25519 -f ~/.ssh/knox-send

These two keys are not password protected, but they are going to be completely restricted in what they can do. This allows us to use them in an automatic way, without the fear of them being abused.
Now bless them. This will ask for the CA password.

	hugh@local$ ssh-keygen -s ~/.ssh/knox-ca -I knox-fifo -O clear -O force-command="cd /tmp; mkfifo -m 600 k; cat - > k; rm k" -n hugh ~/.ssh/knox-fifo.pub
	hugh@local$ ssh-keygen -s ~/.ssh/knox-ca -I knox-send -O clear -O force-command="./zfs-receive.sh" -n root ~/.ssh/knox-send.pub

Terrified? Don't be. We're signing the keys we just created and specifying that if they are presented to the remote server, the only thing they can do is execute the described command. In the first case we create a [*fifo*](https://www.freebsd.org/cgi/man.cgi?query=mkfifo&sektion=1) on the */tmp* memory disk that we write to from *stdin*. This of course, will block until someone reads from it, and that someone is the *zfs-receive.sh* script that we call next, as root. Upon reading the *fifo* the key is transferred directly from our local system to the *geli* process and never touches the disk, or the RAM disk.

And before you complain, that's not a [*useless use of cat*](https://image.slidesharecdn.com/youcodelikeasysadmin-141120122908-conversion-gate02/95/you-code-like-a-sysadmin-confessions-of-an-accidental-developer-10-638.jpg?cb=1416487010), it's required for *tcsh*.

Let's add some shortnames for those keys in *~/.ssh/config*.

	Host knox-fifo
		User hugh
		HostName 192.168.1.23
		IdentityFile ~/.ssh/knox-fifo

	Host knox-send
		User root
		HostName 192.168.1.23
		IdentityFile ~/.ssh/knox-send

Final Approach
--------------
I trust you're quite excited at this point. Let's take a fresh snapshot of our local pool and send it. This will involve sending the entire dataset initially, which is likely a lot of data and is the reason we specified a local network address in **~/.ssh/config**.

	hugh@local$ snapname="$(date -u '+%FT%TZ')"
	hugh@local$ zfs snapshot -r "wd@$snapname"

Snapshots will be given names of the form *'2015-07-24T16:14:10Z* ([ISO 8601 format)](https://en.wikipedia.org/wiki/ISO_8601). The time stamp is from UTC so it will probably be a few hours off from your local time. If you're convinced you'll never change timezone you could change this, but it's hardly an inconvenience.

Drum roll please...

	hugh@local$ ssh knox-fifo < ~/.ssh/knox-geli-key &
	hugh@local$ zfs send -Rev "wd@$snapname" | ssh knox-send

Your data is now safe, secure, and far away. Accessible to only someone with your SSH key (or physical access) and readable only by someone with your geli key.

Incremental Backups
-------------------
All that was a lot of work, but we can automate the rest with a simple script.

To take a snapshot at the current time:

	hugh@local$ ~/backup.sh snapshot

To preview the changes between your latest snapshot and the latest one on the remote system:

	hugh@local$ ~/backup.sh preview

To send those changes:

	hugh@local$ ~/backup.sh backup

To snapshot and send without previewing:

	hugh@local$ ~/backup.sh snapback

Do this once a day, week, whenever and your backups will always be fresh. Remember that ZFS snapshots are cheap (use *'zfs list -t snapshot'* to admire them) so feel free to make many.

Note that the way we send the snapshots will remove any data on the remote pool that isn't on the local pool - so don't store anything there manually. Store it in the local pool and let it propagate automatically.

Also be aware, that there isn't currently support for resuming failed transfers, so they'll have to be restarted. With small, regular snapshots this shouldn't pose much of an issue, and it is an [upcoming feature](http://www.slideshare.net/MatthewAhrens/openzfs-send-and-receive).

Here's the whole script, save it as *~/backup.sh* on your local machine.

	#!/bin/sh

	last_sent_file=~/.zfs-last-sent
	[ ! -f "$last_sent_file" ] && touch "$last_sent_file"

	latest_remote="$(cat "$last_sent_file")"
	[ -z $latest_remote ] && echo "remote state unknown; set it in $last_sent_file"

	latest_local="$(zfs list -H -d1 -t snapshot\
		| grep -e '-[0-9][0-9]T[0-9][0-9]:' \
		| cut -f1 \
		| sort \
		| tail -n 1)"

	snapshot() {
		zfs snapshot -r "wd@$(date -u '+%FT%TZ')"
	}

	send_incremental_snapshot() {
		ssh knox-fifo < ~/.ssh/knox-geli-key &
		sleep 2
		zfs send -RevI "$latest_remote" "$latest_local" \
		| ssh knox-send
	}

	preview() {
		zfs diff "$latest_remote" "$latest_local" | less
		echo "Size in MB:" $(echo $snapshot_size / 1024^2 | bc)
	}

	backup() {
		send_incremental_snapshot && echo "$latest_remote" > "$last_sent_file"
	}

	case "$1" in
		backup) backup ;;
		preview) preview ;;
		snapshot) snapshot ;;
		snapback) snapshot; backup ;;
		*) echo "Commands are: snapshot, backup, preview, snapback"
	esac

You'll have to make it executable too:

	hugh@local$ chmod 744 ~/backup.sh

If you're still in the same shell that you ran the initial backup from, we can set the *remote state* file now.

	hugh@local$ echo "wd@$snapname" > .zfs-last-sent

Physically Placing Your Remote System
=====================================
Now we can place the backup system in its permanent location. This is highly subjective but here are a few points to bear in mind:

* Connect the system to the modem/gateway via Ethernet. Not Wi-Fi.
* Try and place it somewhere out of the way, so it can gather dust in peace.
 * (If necessary, instruct the home-keeper not to dust it.)
* Be respectful and use as few power sockets as possible. A simple [doubler](https://en.wikipedia.org/wiki/AC_power_plugs_and_sockets_-_British_and_related_types#/media/File:Doubler_and_tripler.jpg) can help here.
 * Use an extension cable to minimise the visible wires. Out of sight, out of mind.
* Expect the system to crash or loose power, set it up to recover without intervention.
 * Configure the BIOS to ignore all boot sources but the root when booting.
 * To power up again if it looses power.
 * To auto-power on at a certain time in case the above fails.
* Give the system a DHCP MAC reservation on the gateway, or a static IP if not possible.
 * Set up port forwarding. Take port 22 if available.
 * Set up a [Dynamic DNS](https://freedns.afraid.org/) name if the modem has a dynamic external IP.
 * Edit */etc/rc.conf* to set a static IP if you can't reserve an address through DHCP.

If it's not possible to use port forwarding, there are some alternatives for connecting to the system:

* [Tor hidden service](https://www.torproject.org/docs/tor-hidden-service.html.en) and SSH via [torsocks](https://github.com/dgoulet/torsocks/).
* IPv6.
* SSH wizardry involving [autossh](http://www.harding.motd.ca/autossh/), proxy commands, and reverse tunnels. In this case your local system, or some mutually accessible proxy system must have a static IP.

A Tor hidden service is probably the most reliable fall back, but it will be slow and it's not really in the spirit of Tor to use it in this way. One especially nice feature is that you can leave your remote system deep within a large network (e.g. your employer or University (get permission)) and as long as Tor can get out, you can get in. No need for a direct connection to the modem or DHCP reservations. Personally, I like to have a hidden service running even if I have port-forwarding working, as a fall back measure. e.g. if the modem were replaced or factory-reset, I could *tor* in and with SSH forwarding connect to the modem's WebUI and set up forwarding again.

Once you're worked out your method, adjust your config file on your **local** machine to use the new Internet accessible name.

	Host knox
		User hugh
		HostName backup.tld.cc # FQDN for Internet routing
		#HostName 192.168.1.20 # Local address for initial backup
		#HostName http://idnxcnkne4qt76tg.onion/ # Tor hidden service

Care & Feeding
==============
Upkeep
-----

From time to time connect into the remote system and check the system logs and messages for anything suspicious. Also consider updating any installed packages and keeping up to date with the STABLE branch. *pkg* and *freebsd-update* make this easy.

	root@knox# less +GF /var/log/messages
	root@knox# pkg upgrade
	root@knox# freebsd-update fetch; freebsd-update install

You will need to reboot if *freebsd-update* makes any changes.

It's also sound practice to occasionally exercise the disks, both your local and the remote one with a *scrub* operation. The instructs ZFS to re-read every block on the disk and ensure that they checksum correctly. Any errors can be found will be logged and they probably signal that you should replace the disk.

	hugh@local$ ssh knox-fifo < ~/.ssh/knox-geli-key &
	hugh@local$ ssh knox-shell
	hugh@knox$ su
	root@knox$ geli attach -dpk /tmp/k
	root@knox$ zpool scrub wd
	root@knox$ sleep 60; zpool status
	.....
	# A considerable time later...
	.....
	root@knox# zpool status # is it done?
	root@knox# zpool detach

*zpool* will give you some information about the speed of the operation and an estimated time to completion. Be aware that your drive is unlocked in this state, and you should detach it once the scrub has completed. It is possible to have it self-detach once completed, with a bit of scripting, but I think this may run afoul of any automated backups.

Extra Encryption
----------------
If the thought of the decryption key for some sensitive data being automatically sent to a system outside of your immediate physical control concerns you, but you still want all the advantages of ZFS, you might consider adding an encrypted volume.

This is a ZFS powered virtual storage device that we can layer GELI encryption on top of, using completely different key material but still stored in the ZFS pool such that it can be snapshotted, have only its changes transferred on backup and have the benefit of strong data integrity.

	root@local# mkdir /wd/vol; chown hugh /wd/vol
	root@local# zfs create -s -V 100G wd/vol
	root@local# geli init -s 4096 /dev/zvol/wd/vol
	root@local# geli attach /dev/zvol/wd/vol
	root@local# newfs -Ujn /dev/zvol/wd/vol.eli
	root@local# mount /dev/zvol/wd/vol.eli /wd/vol

I suppose you could use ZFS instead of UFS on the new volume, if you have a [totem](https://www.google.ie/search?q=inception+totem&tbm=isch), but it's probably more trouble than it's worth.

*/wd/vol* is now available for secure storage. The *-s* flag to *zfs create* indicates a *sparse allocation*; the system won't reserve the full 100GiB and won't allocate any more data than you actually write to it. While 100GiB is the most it can hold, you can use ZFS properties to increase the volume size and then *growfs* if you ever hit that limit (*geli* may need to be informed of the resize too).

When you've finished using the encrypted drive, unmount it. Remember not to have any shells active in the directory or they'll hold it open.

	root@local# umount /wd/vol
	root@local# geli detach /dev/zvol/wd/vol.eli

To mount the volume for further use:

	root@local# geli attach /dev/zvol/wd/vol
	root@local# mount /dev/zvol/wd/vol.eli /wd/vol

You may wish to define some shell functions (using *sudo*) to handle the attaching and detaching. The contents of vol will be included in any snapshots and will be sent to the remote system during *zfs send*. I recommend having the volume unmounted and detached before snapshotting though.

Disaster Recovery
-----------------
(*'Disaster'* is a strong word, and implies that real damage has been done, let's instead refer to these issues as *'difficulties'*.)

One day, one of the following things will happen:

* The motor in your USB drive will fail.
* The GoldenEye will be fired.
* A power surge will blow the regulator on the old laptop.
* Someone will knock the remote drive onto the ground while cleaning.
* A drive head will turn masochistic.
* Gamma ray bursts will flip your bits.
* The drive housing the OS will fail.

In all but the last case, we must consider the drive totally lost. It might happen to your local drive first, because it experiences more activity than the backup. It might happen to the remote drive first, because it lives in a room without central heating and is subject to wider temperature fluctuations. No matter how it happens, **it is going to happen**.

*What shall we do when it does?* Simple. Buy a new drive. Set it up as above, create the first backup and then the incrementals as you've always done. Recycle the old drive. There's no need to worry about wiping it clean because everything is encrypted. It is enough to destroy whatever copies of the encryption key you have lying around.

*I deleted a file by accident, can I recover it from a snapshot?* Naturally, you don't even need to access the remote system, snapshots are accessible through the hidden *.zfs* directory at the root of your pool. e.g. */wd/.zfs/snapshot/2015-07-24T23:35:18Z*

*What if the backup computer dies, but the drive is okay?* Recycle the computer. Buy/liberate another one, install FreeBSD as above, then just connect the drive and carry on.

*What about slow, creeping drive death, as opposed to total failure?* ZFS has your back. Take a look at '*zpool status*' every now and then on both machines (the remote will have to be attached of course). If you see any checksum errors, buy a new disk. Every so often, run '*zpool scrub*' on both disks to have ZFS read and verify every sector, then check the status and do what you need to do. Life is too short for bad hard disks, and 2TiB is a lot of data to loose.

*My local disk failed, can I swap in my backup?* Probably. Use *geli* to attach it locally (with the key) and then use '*zpool import*'. Then buy a new drive and go through the motions again.

*My local disk failed, but I can't physically access the remote one, what do I do?* You've got your SSH and GELI keys backed up somewhere, right? Use those to access the remote machine and pull down any files you need (mount the datasets with *'zfs mount -a'*). You *could* try a full backup onto a new disk over the Internet, but you'll be waiting a while, and your friendly server co-location administrators might be getting calls from their ISP. A better approach would be to buy a new drive, have it delivered to wherever the remote system lives and have someone connect it. Set it up as a second pool (use *geli*), do a local send/receive and once it holds a full copy politely ask that it be posted to you. Note: Some systems can't supply enough USB power for two high drain device like hard drives. If you're using a USB powered drive on the machine, connect the second drive through a powered hub or use one that has its own power.

Further Reading
==============

I would first recommend the handbook sections on [zpool](https://www.freebsd.org/doc/handbook/zfs-zpool.html) and [zfs](https://www.freebsd.org/doc/handbook/zfs-zfs.html), followed by their respective *man* pages. They're long, but you've already come this far. [geli](https://www.freebsd.org/cgi/man.cgi?geli(8)) too, is required reading.

Here are some videos discussing ZFS:

* [OpenZFS Overview](https://www.youtube.com/watch?v=RQlMDmnty80)
* [OpenZFS Remote Replication](https://www.youtube.com/watch?v=RQlMDmnty80)

Thank you for your attention, may you never need anything this guide helps prevent against. Please send details of any mistakes or areas for improvement to *obrien.hugh* at the Google mail system.
