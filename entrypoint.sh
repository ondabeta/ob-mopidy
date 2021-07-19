#!/bin/bash

if [ -z "$PULSE_COOKIE_DATA" ]
then
    echo -ne $(echo $PULSE_COOKIE_DATA | sed -e 's/../\\x&/g') >$HOME/pulse.cookie
    export PULSE_COOKIE=$HOME/pulse.cookie
fi

cat /config/mopidy.conf.base | gomplate > /config/mopidy.conf 

exec "$@"
