#! /bin/sh
#wrapper script for trang

if [ "$TRANG_HOME" = "" ]; then
	if [ "$TOOLROOT" = "" ]; then
		echo ${0}: ERROR - cannot locate trang.jar file - please set \$TOOLROOT or \$TRANG_HOME
	else
		TRANG_HOME="$TOOLROOT/java/lib"
	fi
fi

java -jar "$TRANG_HOME/trang.jar" "$@"
exit $?
