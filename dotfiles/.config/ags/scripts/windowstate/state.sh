#!/bin/bash
set -x
SWIPE_DIRECTION=$1
WINDOW_NAME=$2
CONFIG_PATH=~/.local/share/windowstate
mkdir -p ${CONFIG_PATH}
case "${SWIPE_DIRECTION}" in
        "right") REVERSE_DIRECTION="left";;
        "left") REVERSE_DIRECTION="right";;
        "up") REVERSE_DIRECTION="down";;
        "down") REVERSE_DIRECTION="up";;
esac
if [ ! -f ${CONFIG_PATH}/${REVERSE_DIRECTION} ]; then
	if [ "${SWIPE_DIRECTION}" == "up" ]; then
	        if [ ! -f "${CONFIG_PATH}/down" ] ; then
			gnome-pie --open 844 &
			exit 0
		else
			ags run-js "App.closeWindow('overview')"
			rm ${CONFIG_PATH}/down
			exit
		fi
	fi
	ags run-js "App.openWindow(\"${WINDOW_NAME}\")"
	echo ${WINDOW_NAME} > ${CONFIG_PATH}/${SWIPE_DIRECTION}
else
	ags run-js "App.closeWindow(\"$(cat ${CONFIG_PATH}/${REVERSE_DIRECTION})\")"
	rm ${CONFIG_PATH}/${REVERSE_DIRECTION}
fi
