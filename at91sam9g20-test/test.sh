#!/bin/sh

#2 LEDS: pin 29, 31
#GENERATOR(PULSE) pin 3
#COUNTER pin 9
#DS18B20 pin 4
#LM75 pins 17,18

./test -q << EOT
gpio . 29 enable output 1
gpio . 31 enable output 1
gpio . 3 enable output 0
counter . init
gpio . 3 1
ds18b20 . 4 presense
EOT

#read board key
key=$(cat key)
#configuration table name
config="$key.config"
#data table name
data="$key.data"
#ask server for board configuration
echo ".dump \"$config\"" | curl -s --upload-file - http://shah32768.sdf.org/cgi-bin/board-get-config.cgi | sqlite3 sensors.db 2> /dev/null
echo "create table \"$data\" (time timestamp, devid text, value float, key text);" | sqlite3 sensors.db 2> /dev/null

get_config() {
	echo "select value from \"$config\" where name=\"$1\";" | sqlite3 sensors.db 
}

./test -q << EOT
gpio . 29 0
gpio . 31 0
gpio . 3 1
EOT

sleep `get_config measure-period`


THERM0="therm-ds18b20"
THERM1="therm-lm75"
COUNTER="counter0"

prepare() {
	echo "gpio . 29 1
		gpio . 31 0
		gpio . 3 1
		ds18b20 . 4 convert" | ./test -q
}

collect() {
	echo "gpio . 29 0
		gpio . 31 1
		gpio . 3 0
		ds18b20 $THERM0 4 read
		counter $COUNTER read
		lm75 $THERM1 0x4F read" |
		./test -q |
		awk -v data=$data -v key=$key '
		BEGIN {
			printf("begin transaction;\n");
		} {
			printf("insert into \"%s\" values (CURRENT_TIMESTAMP,\"%s\",\"%s\",\"%s\");\n", data, $1, $2, key);
		} END {
			printf("end transaction;\n\n")
		}
	' | sqlite3 sensors.db
}

send() {
	echo "gpio . 29 1
		gpio . 31 1" | ./test -q
		echo ".dump \"$data\"" | sqlite3 sensors.db | [[ `curl -s --upload-file - $(get_config data-cgi)` == "OK" ]]
}

delete() {
	echo "gpio . 29 0
		gpio . 31 0" | ./test -q
		echo "delete from \"$data\";" | sqlite3 sensors.db
}

cnt=0
while true
do
prepare
sleep `get_config measure-period`
collect
cnt=`expr $cnt + 1`
[[ $cnt == `get_config send-period` ]] && cnt=0 && send && delete
done


#echo "create table data (time timestamp, devid text, value float);"
#echo "create table config (name text, value text);"
#echo "select time,value,devid from outbox where devid='board1.counter';" | sqlite3 sensors.db
#echo "select time,value,devid from outbox where id between 10 and 15;" | sqlite3 sensors.db
#delete from outbox where id between 0 and 35000
#select * from outbox where id between (select min("id") from outbox)  and (select min("id")+2 from outbox);
#select * from outbox where id between (select max("id")-16 from outbox) and (select max("id") from outbox) and devid="board1.term0";
#select id,datetime(time, 'unixepoch'),devid,value from outbox where id between (select max(id)-32 from outbox) and (select max(id) from outbox);
#insert into data (time,devid,value) select"0", devid,"2.02" from devices where devid="invalid.sensor" and status="0";
#create table devices (id integer primary key, devid text, status integer, description text, unique(devid) on conflict replace);
#select distinct value from data where devid="board1.therm-ds18b20";
#select count(*) from(select * from t00000000 where x like "%abcd" union all select * from t00000001 where x like "%abcd"  union all select * from t00000002 where x like "%abcd" union all select * from t00000003 where x like "%abcd" union all select * from t00000004 where x like "%abcd" union all select * from t00000005 where x like "%abcd" union all select * from t00000006 where x like "abcd%" union all select * from t00000007 where x like "%abcd" union all select * from t00000008 where x like "%abcd" union all select * from t00000009 where x like "%abcd");
#select * from t00000000 where x like "abcd%" union all select * from t00000001 where x like "abcd%"  union all select * from t00000002 where x like "abcd%" union all select * from t00000003 where x like "abcd%" union all select * from t00000004 where x like "abcd%" union all select * from t00000005 where x like "abcd%" union all select * from t00000006 where x like "abcd%" union all select * from t00000007 where x like "abcd%" union all select * from t00000008 where x like "abcd%" union all select * from t00000009 where x like "%abcd"
#insert into test values(CURRENT_TIMESTAMP);;
