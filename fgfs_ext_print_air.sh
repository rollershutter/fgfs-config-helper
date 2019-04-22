#!/bin/bash
#
# bash script to show external aircrafts (start-name and description)
#
# fgfs_ext_print_air.sh
#  ver: 0003 ge
#
# author: sebastian github.com/rollershutter
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

TARGET="-set.xml"
printf -v PAD '%0.1s' "#"{1..74}


## function: ###########################################################
check_valid_aircrafts_path() {
	local files=("$1/"*"$TARGET");
	if [ -f "$files" ]; then
		for c_file in "$1/"*"$TARGET"; do
			VALID_AIRCRAFTS[${#VALID_AIRCRAFTS[@]}]="$c_file"
		done
	fi
}

print_overlap() {
	tmp_ifs="$IFS"; IFS=$'\n';
	local c_name="$1"; local c_over=(${!c_name})
	IFS="$tmp_ifs";

	if [ ${#c_over[@]} -gt 1 ]; then
		printf ' %s\n' "${c_over[0]}"
		for c_e in "${c_over[@]:1}"; do
			printf '   %-28s %s\n' " " "${c_e}"
		done
	else
		printf ' %s\n' "${c_over}"
	fi
}


## main: ###############################################################
if [ "$1" == "-s" ]; then
	SILENT_MOD="on"
else
	SILENT_MOD=""
fi

######
if [ "$2" != "" ]; then
	C_IN=("$@")
	AIRPATHS=("${C_IN[@]:1}")
	echo "## AIRPATHS: [${AIRPATHS[@]}]"
else
	echo "## no input paths, exiting..."
	exit 1
fi

## add colours
if [ -z "$SILENT_MOD" ]; then												## print nice
	STR_F_ADIR='\e[1;31m%b\e[0m'
	STR_F_AIRC='\e[1;36m%b\e[0m'
	STR_F_SHRT='\e[0;36m%-28b\e[0m'
else
	STR_F_ADIR='%b'
	STR_F_AIRC='%b'
	STR_F_SHRT='%-28b'
fi

#[ -z "$SILENT_MOD" ] \
#	&& printf '## maximise me, then hit any KEY:' \
#		&& read -sn1 go_on && echo

##
for air_collection in "${AIRPATHS[@]}"; do 
	[ -z "$SILENT_MOD" ] \
		&& printf "\r$STR_F_ADIR\n" "$PAD" "${air_collection}:"; ##printf "\r$STR_F_ADIR\n" "$PAD" "# ${air_collection}:"; 

	for p in "$air_collection"/*; do 
		if [ -d "$p" ]; then
			VALID_AIRCRAFTS=()
			check_valid_aircrafts_path "$p" 
			if [ ${#VALID_AIRCRAFTS[@]} -ne 0 ]; then
				[ -z "$SILENT_MOD" ] \
					&& printf " $STR_F_AIRC:\n" "$(basename "$p")"; ##printf "# $STR_F_AIRC:\n" "$(basename "$p")"; 

				v_names=();
				for e in "${VALID_AIRCRAFTS[@]}"; do 
					e_nam="$(basename "$e")"; 
					v_names[${#v_names[@]}]="${e_nam%%-set*}"; 
					printf "   $STR_F_SHRT" "${v_names[$((${#v_names[@]}-1))]}"; 

					if [ -z "$SILENT_MOD" ]; then
						c_desc="$(awk -F"<|>" '$0 ~ /description*/ {print $3}' "$e")"; 
						[ -z "${c_desc}" ] \
							&& c_desc="n.a."; 
						print_overlap "c_desc";
					else
						printf '\n'
					fi 
				done
			fi
		fi
	done
done

exit 0
