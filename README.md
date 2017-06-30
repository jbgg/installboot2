# installboot2
In OpenBSD the PBR (partition boot record) is responsible for load /boot in memory.
The code of PBR is called biosboot.
The configuration of biosboot is handled by installboot program.
I have use with the device of the system and it works fine,
but I tried to make it with another device (a flash memory) and it didn't work.
Maybe I didn't use it correctly,
so I have created a script which makes that work.
I have called ib.sh, and we can use as follow:
# sh ib.sh /dev/sd1c 3
where /dev/sd1c is the device and 3 is the inode number.
