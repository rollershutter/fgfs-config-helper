#!/bin/bash
#
# bash script to get external airpaths by user-input
#
# fgfs_ext_get_airpaths.sh
#  ver: 0003 gf
#
# idea is to source this and get the array "AIRPATHS" in the parent script
#
# author: rollershutter@github.com
#		  ('rollershutter' at flightgear-forums
#			forum.flightgear-de.net
#			forum.flightgear.org)
##


########################################################################
## variables ###########################################################
#OPT_AIRPATH_ROOT="$HOME/_opt_progs"

## you could enter your external paths here in "AIRPATHS": #############
#AIRPATHS=("$OPT_AIRPATH_ROOT/fg_aircraft_svn" \
#			"$OPT_AIRPATH_ROOT/fg_air_3_0" \
#			"$OPT_AIRPATH_ROOT/theomega" \
#			"$OPT_AIRPATH_ROOT/buckaroo")

TEXT_CP="einen Pfad mit Flightgear Flug-/Fahrzeugen auswählen!" ## "choose airpath"
TXT_SHORT_CP="Pfad auswählen" ## "choose airpath"
TXT_MORE="einen weiteren $TXT_SHORT_CP?" ## "choose another path?"
#TXT_EXIT=" TASTE drücken zum Schliessen!" ## "press KEY to exit"
TXT_ADD_FG_AIR="FG_ROOT/Aircraft hinzufügen?"

FG_AIRPATH="/usr/share/games/flightgear/Aircraft"


## function: ###########################################################
user_select_path() {
#	##test zenity last selected
	if [ ${#AIRPATHS[@]} -ne 0 ]; then
		## for zenity, to preselect last used/selected path
		local XT_LOC_ARG="--filename=${AIRPATHS[$((${#AIRPATHS[@]} - 1))]}" ## "--filename=$(dirname "${AIRPATHS[$((${#AIRPATHS[@]} - 1))]}")"
#	else
#		echo "## no airpath yet, first run"
	fi
	#echo "[$XT_LOC_ARG]"

	#if [ $(check_command_v "zenity") -eq 0 ]; then
	if [ "$USER_IFACE" == "Zenity" ]; then
		##test zenity last selected (XT_LOC_ARG)
		USR_ENTRY=($(zenity --file-selection \
					$XT_LOC_ARG \
					--directory \
					--text "$TEXT_CP" \
					--title "$TXT_SHORT_CP"))
	else
		printf '%s\n' "## $TEXT_CP (hit RETURN to confirm)"
		read USR_ENTRY
	fi
}

check_command_v() {
	command -v "$1" >/dev/null 2>&1 #\#
		return $?
#		&& return 0 \
#		|| return 1
}


## main: ###############################################################
#USER_IFACE="Console" ## "Zenity" 										## hm, silent mode (-s) is needed for compatibility with fgfs-start-script, then it is a mess with user-prompt-description texts...
########################################################################

## determine quit mode
if [ "$1" != "-s" ]; then
	QUIET_MODE="on"
else
	QUIET_MODE=""
fi

## check if zenity is installed?
if check_command_v "zenity"; then
	USER_IFACE="Zenity"
	## due to gtk errors
	export NO_AT_BRIDGE=1
else
	printf '%s\n' "Zenity is not installed, might install with:" " apt-get install zenity"
	USER_IFACE="Console"
fi
#USER_IFACE="Console"													## testing

#C_PWD=$(pwd)


######
if [ -n "$2" ]; then
	AIRPATHS=("$2") ##AIRPATHS=() ##("$FG_AIRPATH") ## AIRPATHS=()
else
	AIRPATHS=()
fi

##
## get user input paths loop
if [ "${#AIRPATHS[@]}" -eq 0 ]; then
	while true; do
		user_select_path
		if [ -d "$USR_ENTRY" ]; then
			AIRPATHS[${#AIRPATHS[@]}]="$USR_ENTRY" ##"$(user_select_path)"
			#echo "[${AIRPATHS[$((${#AIRPATHS[@]} - 1))]}]"
			[ -n "$QUIET_MODE" ] && echo "## [${AIRPATHS[$((${#AIRPATHS[@]} - 1))]}]"
			#printf '%s' "main: checking command returns: $(command -v "zenity" >/dev/null 2>&1)"
		fi

		#if [ $(check_command_v "zenity") -eq 0 ]; then
		if [ "$USER_IFACE" == "Zenity" ]; then
			zenity --question --text "$TXT_MORE" --title "$TXT_MORE" \
				|| break
		else
			printf '## %s' "$TXT_MORE (y/KEY) - ja/nein"
			read -sn1 ps_m && echo " $ps_m";
			[ "$ps_m" != "y" ] \
				&& break
		fi
	done
fi

if [ -n "$QUIET_MODE" ]; then
	if [ "$USER_IFACE" == "Zenity" ]; then
		zenity --question --text "$TXT_ADD_FG_AIR" --title "$TXT_ADD_FG_AIR" \
			&& AIRPATHS=("$FG_AIRPATH" "${AIRPATHS[@]}")
			##|| break
	else
		printf '## %s' "$TXT_ADD_FG_AIR (y/KEY) - ja/nein"
		read -sn1 ps_m && echo " $ps_m"
		[ "$ps_m" == "y" ] \
			&& AIRPATHS=("$FG_AIRPATH" "${AIRPATHS[@]}")
	fi
fi


######
##
#[ -n "$QUIET_MODE" ] \
#	&& { printf '## maximise me, then hit any KEY:' \
#		&& read -sn1 go_on \
#			&& echo; } 


######
## debug
#[ "$USER_IFACE" != "Zenity" ] && printf '## %s\n' "ps_m: $ps_m" ## "go_on: $go_on"

#printf '## %s\n' "last USR_ENTRY: [${USR_ENTRY}]"
#printf '## %s\n' "for testing, debug the collected inputs:" "[${AIRPATHS[@]}]"

## this is the NEW usr-input-script-module, so exit (this could be sourced to use the internal variables outside in the sourcing instance...)
## when sourced, this exit exits the parent...
#exit 0
