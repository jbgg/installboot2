#!/bin/sh
## ib01.sh ##

## TODO: make backup of pbr


# programexit arg1
# 	exit with error arg1
programexit()
{
	case $1 in
		0) # no arguments
			echo "usage: `basename $0` device inodenum"
			echo " example: `basename $0` /dev/wd0c 3"
			;;
		1) # file does not exist
			echo "file ${devicename} does not exist";;
		2) # read mbr error
			echo "read mbr error";;
		3) # mbr bad signature
			echo "mbr bad signature";;
		4) # no OpenBSD partition in DOS partition table
			echo "no openBSD partition in DOS partition table";;
		5) # read pbr error
			echo "read pbr error";;
		6) # pbr signature error
			echo "pbr signature error";;
		7) # read disklabel error
			echo "read disklabel error";;
		8) # disklabel magic number error
			echo "disklabel magic number error";;
		9) # file system type error
			echo "file system type error";;
		10) # read superblock error
			echo "read superblock error";;
		11) # superblock magic number error
			echo "superblock magic number error";;
		12) # inopb data of superblock is zero
			echo "inopb data of superblock is zero";;
		13) # read inodeblock error
			echo "read inodeblock error";;
		14) # file size needs 64 bits number
			echo "file size needs 64 bits number";;
		15) # write to pbrfile error
			echo "write to pbrfile error";;
		16) # write to device pbr  error
			echo "write to device pbr error";;
		*) # general case?
			;;
	esac

	if [ ! -z ${cleanfiles} ];then
		# debug
		echo " ** delete ${cleanfiles}"
		# delete clean files
		rm -f ${cleanfiles}
	fi
	exit
}







## test arguments ##
if [ "$#" -le '1' ]; then
	programexit 0
fi



# save device name
devicename=$1
# save inode number
inodenum=$2

# debug
echo " ** devicename=${devicename}"
echo " ** inodenum=${inodenum}"

## check if device exists ##
if [ ! -a "$1" ]; then
	programexit 1
fi




## reading mbr ##

# tmp file for mbr
mbrfile=`mktemp`

# debug
echo " ** mbrfile=${mbrfile}"

# for future clean
cleanfiles="${cleanfiles} ${mbrfile}"

# copy first sector of device
dd if=${devicename} of=${mbrfile} bs=512 count=1 2>/dev/null

# check if dd works fine
if [ "$?" -ne '0' ]; then
	programexit 2
fi

# check signature
sig=`xxd -g 2 -l 2 -s $((0x1fe)) ${mbrfile} | awk '{print $2}'`
echo " ** sig=${sig}"
if [ "${sig}" != "55aa" ]; then
	programexit 3
fi

# look for an OpenBDS partition
# TODO: look for in extension partitions
typeoff=$((0x1be+0x4))
for pnum in 0 1 2 3; do
	type=`xxd -g 1 -l 1 -s ${typeoff} ${mbrfile} | awk '{print $2}'`
	if [ ${type} == "a6" ];then
		break
	fi
	typeoff=`expr ${typeoff} + $((0x10))`
done

if [ ${type} != "a6" ];then
	programexit 4
fi

# debug
echo " ** type=${type}"
echo " ** pnum=${pnum}"


## get start sector of partition ##
startoff=`expr ${typeoff} + 4`
startsec=$((0x`xxd -e -g 4 -l 4 -s ${startoff} ${mbrfile} | awk '{print $2}'`))

# debug
echo " ** startoff=${startoff}"
echo " ** startsec=${startsec}"


## read pbr ##
# this will be modifid later

# tmp file for pbr
pbrfile="pbr.data"
rm -f ${pbrfile}

# debug
echo " ** pbrfile=${pbrfile}"

# for future clean
#cleanfiles="${cleanfiles} ${pbrfile}"

# copy first sector of device
dd if=${devicename} of=${pbrfile} bs=512 skip=${startsec} count=1 2>/dev/null

# check if dd works fine
if [ "$?" -ne '0' ]; then
	programexit 5
fi

# check signature
sig=`xxd -g 2 -l 2 -s $((0x1fe)) ${pbrfile} | awk '{print $2}'`
echo " ** sig=${sig}"
if [ "${sig}" != "55aa" ]; then
	programexit 6
fi


## read disklabel ##

# tmp file for disklabel
disklabelfile=`mktemp`

# debug
echo " ** disklabelfile=${disklabelfile}"

# for future clean
cleanfiles="${cleanfiles} ${disklabelfile}"

# copy first sector of device
dd if=${devicename} of=${disklabelfile} bs=512 skip=`expr ${startsec} + 1` count=1 2>/dev/null

# check if dd works fine
if [ "$?" -ne '0' ]; then
	programexit 7
fi

# check magic number of disklabel
magic=`xxd -e -g 4 -l 4 -s $((0x0)) ${disklabelfile} | awk '{print $2}'`
echo " ** magic=${magic}"
if [ "${magic}" != "82564557" ]; then
	programexit 8
fi
magic2=`xxd -e -g 4 -l 4 -s $((0x84)) ${disklabelfile} | awk '{print $2}'`
echo " ** magic2=${magic2}"
if [ "${magic}" != "82564557" ]; then
	programexit 8
fi

# TODO: check n_partitions and checksum


## get data of first partition (a) ##
startpart=$((0x`xxd -e -g 4 -l 4 -s $((0x98)) ${disklabelfile} | awk '{print $2}'`))
fstype=`xxd -e -g 1 -l 1 -s $((0xa0)) ${disklabelfile} | awk '{print $2}'`

# debug
echo " ** startpart=${startpart}"
echo " ** fstype=${fstype}"

# TODO: get high data of partition offset

# check file system type of partition
if [ ${fstype} != "07" ]; then
	programexit 9
fi



## read superblock ##

# tmp file for superblock
superblockfile=`mktemp`

# debug
echo " ** superblockfile=${superblockfile}"

# for future clean
cleanfiles="${cleanfiles} ${superblockfile}"

# copy first sector of device
dd if=${devicename} of=${superblockfile} bs=512 skip=`expr ${startpart} + $((0x10))` count=$((0x10)) 2>/dev/null

# check if dd works fine
if [ "$?" -ne '0' ]; then
	programexit 10
fi

## check superblock magic number ##
magic=`xxd -e -g 4 -l 4 -s $((0x55c)) ${superblockfile} | awk '{print $2}'`

# debug
echo " ** magic=${magic}"

if [ ${magic} != '00011954' ]; then
	programexit 11
fi


## get superblock data ##

bsize=$((0x`xxd -e -g 4 -l 4 -s $((0x30)) ${superblockfile} | awk '{print $2}'`))
fsize=$((0x`xxd -e -g 4 -l 4 -s $((0x34)) ${superblockfile} | awk '{print $2}'`))
ipg=$((0x`xxd -e -g 4 -l 4 -s $((0xb8)) ${superblockfile} | awk '{print $2}'`))
fpg=$((0x`xxd -e -g 4 -l 4 -s $((0xbc)) ${superblockfile} | awk '{print $2}'`))
cgoffset=$((0x`xxd -e -g 4 -l 4 -s $((0x18)) ${superblockfile} | awk '{print $2}'`))
ntrak=$((0x`xxd -e -g 4 -l 4 -s $((0xa4)) ${superblockfile} | awk '{print $2}'`))
iblno=$((0x`xxd -e -g 4 -l 4 -s $((0x10)) ${superblockfile} | awk '{print $2}'`))
inopb=$((0x`xxd -e -g 4 -l 4 -s $((0x78)) ${superblockfile} | awk '{print $2}'`))
fragshift=$((0x`xxd -e -g 4 -l 4 -s $((0x60)) ${superblockfile} | awk '{print $2}'`))
nspf=$((0x`xxd -e -g 4 -l 4 -s $((0x7c)) ${superblockfile} | awk '{print $2}'`))



# debug
echo " ** bsize=${bsize}"
echo " ** fsize=${fsize}"
echo " ** ipg=${ipg}"
echo " ** fpg=${fpg}"
echo " ** cgoffset=${cgoffset}"
echo " ** ntrak=${ntrak}"
echo " ** iblno=${iblno}"
echo " ** inopb=${inopb}"
echo " ** fragshift=${fragshift}"
echo " ** nspf=${nspf}"



# get cylinder
cyl=`expr ${inodenum} / ${ipg}`

# get block number of inode
if [ ${ntrak} -eq 0 ];then
	inodeblocknum=$(( ${cyl} * ${fpg} + ${cgoffset} * ${cyl} + ${iblno} ))
else
	inodeblocknum=$(( ${cyl} * ${fpg} + ${cgoffset} * ( ${cyl} % ${ntrak} ) + ${iblno} ))
fi

# get offset (in bytes) of inode inside the block
if [ ${inopb} -eq 0 ];then
	programexit 12
fi
inodeoffset=$(( ( ${inodenum} % ${inopb} ) * 0x80 ))

# debug
echo " ** inodeblocknum=${inodeblocknum}"
echo " ** inodeoffset=${inodeoffset}"





## read inode block ##

# tmp file for inodeblock
inodeblockfile=`mktemp`

# debug
echo " ** inodeblockfile=${inodeblockfile}"

# for future clean
cleanfiles="${cleanfiles} ${inodeblockfile}"

# copy first sector of device
dd if=${devicename} of=${inodeblockfile} bs=512 skip=$((${startpart} + ${inodeblocknum} * ${nspf} )) count=${bsize} 2>/dev/null

# check if dd works fine
if [ "$?" -ne '0' ]; then
	programexit 13
fi



# get file size
filesize=$((0x`xxd -e -g 4 -l 4 -s $((${inodeoffset} + 8)) ${inodeblockfile} | awk '{print $2}'`))
filesizeh=$((0x`xxd -e -g 4 -l 4 -s $((${inodeoffset} + 8 + 4)) ${inodeblockfile} | awk '{print $2}'`))

if [ ${filesizeh} -ne '0' ]; then
	programexit 14
fi

# debug
echo " ** filesize=${filesize}"


# get data for biosboot

inodeblk=${inodeblocknum}
inodedbl=$(( ${inodeoffset} + 0x200 + 0x28 ))
nblocks=$(( ( ${filesize} + ${bsize} -1 ) / ${bsize} ))
p_offset=${startpart}

# debug
echo " ** inodeblk=${inodeblk}"
echo " ** inodedbl=${inodedbl}"
echo " ** nblocks=${nblocks}"
echo " ** p_offset=${p_offset}"



# copy data to pbrfile
printf "\x`printf '%02x' $(( ${inodeblk} & 0xff))`\x`printf '%02x' $(( ${inodeblk} >> 8 & 0xff))`\x`printf '%02x' $(( ${inodeblk} >> 16 & 0xff))`\x`printf '%02x' $(( ${inodeblk} >> 24 & 0xff))`" | dd of=${pbrfile} bs=1 count=4 seek=$((0xa5)) conv=notrunc 2>/dev/null
if [ "$?" -ne '0' ]; then
	programexit 15
fi

printf "\x`printf '%02x' $(( ${inodedbl} & 0xff))`\x`printf '%02x' $(( ${inodedbl} >> 8 & 0xff))`\x`printf '%02x' $(( ${inodedbl} >> 16 & 0xff))`\x`printf '%02x' $(( ${inodedbl} >> 24 & 0xff))`" | dd of=${pbrfile} bs=1 count=4 seek=$((0xb2)) conv=notrunc 2>/dev/null
if [ "$?" -ne '0' ]; then
	programexit 15
fi

printf "\x`printf '%02x' $(( ${nblocks} & 0xff))`\x`printf '%02x' $(( ${nblocks} >> 8 & 0xff))`" | dd of=${pbrfile} bs=1 count=2 seek=$((0xb7)) conv=notrunc 2>/dev/null
if [ "$?" -ne '0' ]; then
	programexit 15
fi

printf "\x`printf '%02x' $(( ${p_offset} & 0xff))`\x`printf '%02x' $(( ${p_offset} >> 8 & 0xff))`\x`printf '%02x' $(( ${p_offset} >> 16 & 0xff))`\x`printf '%02x' $(( ${p_offset} >> 24 & 0xff))`" | dd of=${pbrfile} bs=1 count=4 seek=$((0x1ac)) conv=notrunc 2>/dev/null
if [ "$?" -ne '0' ]; then
	programexit 15
fi




## copy pbrfile to device pbr ##
dd if=${pbrfile} of=${devicename} bs=512 count=1 seek=${startsec} conv=notrunc 2>/dev/null
if [ "$?" -ne '0' ]; then
	programexit 16
fi




# debug
echo " ** delete ${cleanfiles}"
# delete temp files
rm -f ${cleanfiles}


echo "-- PBR modified --"



