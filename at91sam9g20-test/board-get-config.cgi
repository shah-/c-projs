#!/usr/bin/env bash
sqlite3 ~/data/sensors.db 2> /dev/null
echo -e "Content-type: text/plain\n\nOK"

