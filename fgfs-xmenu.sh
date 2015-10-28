#!/bin/bash
#
# flightgear option-helper
#
# fgfs-xmenu.sh
#  ver: 01007 rework_6_quap_cleaned
#
# bash-script to run and edit your custom config-options
# -should be executed within a viewable shell to see what you do,
#  but script will check that and restart if file is executed anyway...
# 
# author: rollershutter@github.com
#		  ('rollershutter' at flightgear-forums
#			forum.flightgear-de.net
#			forum.flightgear.org)
#
######
# TODO: -tput spacing [recheck]
#		-[docu docu docu]
#		-cleaning
#		-user workflow (y/n | n° w/wo RETURN | confirm choosen | etc.)
#		-reconsider the grown mess
#		(-there has been several dirty change-option hacks that are not compatible to the output of --help --verbose anymore (test: (or had been disabled due to similar other option-strings))? -still working for switching enable/disable)
#		(---season --carrier --nav1 --dme --wind)
#		-external find custom airpaths reworked							## [-done]
#		-menu:
#		  -the menu has globals to set:
#			 (menu_texts, action, TOG_GROUP_NUM, CHOSEN, TOG_QUIT)
#			 -maybe define a global array in FuMain and only set the values to keys 'menu_texts'/'action'
#		  -check if menu could be separated...
#		-refactoring loc/glob, ...
########################################################################


########################################################################

### Funktionen #########################################################
CheckNumber() {
	if [[ "$1" != "" ]] && [[ "${1//[[:digit:]]/}" == "" ]]; then
		return 0
	else
		echo "Bitte Nummer eingeben..."
		return 1
	fi
}

GetCurPosition() { 														## please just run this (get_pos, not xy=$(get_pos))
	stty -echo;
	echo -n $'\e[6n';
	read -d R CUR_ROW;
	stty echo;
	CUR_ROW="${CUR_ROW#??}"
}

##
PrintConfig() {
	[ "${#CURRENT_CONFIG[@]}" -eq 0 ] \
		&& preview_mess="keine Konfiguration" \
		|| preview_mess="Konfiguration: 
[${CURRENT_CONFIG[@]}]"
	printf '%s\n\n' "$preview_mess"
}

CheckCommandExists() {
	command -v $curr_comm >/dev/null 2>&1 \
		&& return 0 \
		|| return 1
}

GetMyPaths() { ## kann einfach in den main? 							## executed once
	exedir="$(dirname "${1#./}")"
	if [ -d "$exedir" ]; then
		MY_REAL_PWD="$exedir"
	else
		MY_REAL_PWD="$(pwd)"
	fi
}

GetPidHostEmulator() {
	pid="$1"
	pid=$(ps -h -o ppid -p $pid 2>/dev/null) 							## s.u.
	ps -h -o comm -p $pid 2>/dev/null
}


########################################################################
## menu-construction
MenuShow() {
	#echo " DEBUG MenuShow(): rnd_count: $4"
	local menugrp=("${!1}")												## chgd to local
	local cntgrps=0														## chgd to local
	printf '%-2s %s\n' " " "$2:"

	if [ ${#menugrp[@]} -gt 20 ]; then
		for (( sm=0; sm<$((${#menugrp[@]}/2)); sm++)); do
			## NEW: shorten the multi-column-view
			local entry_1="${menugrp[$((sm*2+0))]}"
			[ ${#entry_1} -gt 30 ] \
				&& entry_1="${entry_1:0:27}..."
			local entry_2="${menugrp[$((sm*2+1))]}"
			[ ${#entry_2} -gt 30 ] \
				&& entry_2="${entry_2:0:27}..."
			printf '%2s%3s %-34s%2s%-3s %-34s\n' \
					" " \
					"$((sm*2+1))" "${entry_1}" \
					" " "$((sm*2+2))" "${entry_2}"
		done

		## print rest if any (rest of num elements / 2)
		if [ "${menugrp[$((sm*2+0))]}" ]; then
			printf '%2s%3s %-34s\n' " " "$((sm*2+1))" "${menugrp[$((sm*2+0))]}"
		fi
	else
		for menuitem in "${menugrp[@]}"; do
			cntgrps=$((cntgrps + 1))
			printf '%-2s%3s %-40s\n' " " "$cntgrps" "$menuitem"
		done
	fi

	if [ "$3" == "back_toggle" ]; then
		printf '%-2s%3s %-40s\n' " " "0" "back/cancel"
	fi
}

##
MenuConstructSingle() {
	local cnam="$1[@]" && menu_texts=("${!cnam}")						## chgd to local ## ACHTUNG: test if menu_texts is needed global (s.b.)
	cnam="$2[@]" && local menu_actions=("${!cnam}")						## chgd to local

	local hint_mess_strings=("bitte auswählen")							## maybe chg that to global message string...
	if [ "$4" == "back_toggle" ]; then
		local min_num=0													## chgd to local
		hint_mess_strings[1]="/abbrechen ($min_num - ${#menu_actions[@]}/0 to cancel):" ## maybe chg that to global message string...
	else
		local min_num=1													## chgd to local
		hint_mess_strings[1]="($min_num - ${#menu_actions[@]}):"		## maybe chg that to global message string...
	fi

	MenuShow "menu_texts[@]" "${3-Hauptmenü}" "$4" $CNT_ROUND			## $cnt_round ## ACHTUNG! this is a global, set in Fu-Main

	ACTION=""															## test: this is global, maybe use a global array (ass.) and only set the key 'action' here to make that clear

	GetCurPosition && cur_pos1="${CUR_ROW%;*}" ## && echo "cur_pos1: $cur_pos1"	## maybe the cur_pos1/ cur_pos2 are global in menu-composition... (check that!) (cur_pos0 is used and set in FuMain as well...)
	while [ -z "$ACTION" ]; do

		tput cup "$cur_pos1" 0 && tput ed

		printf '\r%s %s' "${hint_mess_strings[@]}"
		read -sn1 tog_menu_action

		## New: check for valid number here, too... (!)
		CheckNumber "$tog_menu_action" || continue
		if [ "${tog_menu_action//[$min_num-${#menu_actions[@]}]/}" == "" ]; then
			if [ $tog_menu_action -eq 0 ]; then
				echo "Auswahl abgebrochen..."
				printf '\n'
				break
			fi

			tput cup "$cur_pos1" 0 && tput ed

			printf '\r%s' "${menu_texts[$(($tog_menu_action-1))]} (y/KEY)?"
			read -n1 -s tog_confirm
			if [ "$tog_confirm" = "y" ]; then

				ACTION="${menu_actions[$(($tog_menu_action-1))]}"
				printf '\n'
			fi
##
		else
			echo "Bitte Nummer von $min_num bis ${#menu_actions[@]} angeben..."
			continue
##
		fi
	done
}

##
MenuChooseEnter(){
	MenuShow "$1" "$2" "" $CNT_ROUND
	local temp_a=("${!1}")												## chgd to local
	local numelements="${#temp_a[@]}"									## chgd to local
	#g_exit=""; while [[ -z $g_exit ]]; do read -sn1 MY_USR_IN; if [ "${MY_USR_IN//[[:digit:]]/}" == "" ]; then echo "hurray: [$MY_USR_IN]"; break; exit_no_need="Buh..."; else echo "please... a number!"; fi; done; echo "[$exit_no_need]"

	while [ -z "$exit_no_need" ]; do
		echo -ne "auswählen/abbrechen (1 - $numelements/0 to cancel) hit ENTER to confirm: "	## bug: falsche zeichen abfrage [-done]
		read toggrp
## New
		CheckNumber "$tog_menu_action" || continue

		if [[ $toggrp -le $numelements ]] && [[ $toggrp -ge 1 ]]; then	## number in expected range...
			## this is right...
			#echo "ok..." ##"hurray"									## number in expected range...
			break
		else
			echo "Bitte Nummer von 0 bis $numelements angeben..."
		fi

		if [ $toggrp -eq 0 ]; then
			echo "Auswahl abgebrochen..."
			break
		fi
##
	done

## set globals
	if [ $toggrp -ne 0 ]; then
		TOG_GROUP_NUM=$((toggrp - 1))
		CHOSEN=${temp_a[$TOG_GROUP_NUM]}
		TOG_QUIT="n"
	else
		TOG_QUIT="y"
		TOG_GROUP_NUM=
		CHOSEN=""
	fi
}


########################################################################
## Fu is Core...
FuActionHelper() {
	case $1 in
		"fu_main") MenuConstructSingle "main_menu_text" "main_menu_actions";;
		"fu_conf") MenuConstructSingle "conf_sub_text" "conf_sub_actions" "${main_menu_text[0]}" "back_toggle";;
		"fu_add") MenuConstructSingle "add_sub_text" "add_sub_actions" "${main_menu_text[1]}" "back_toggle";;
		"fu_run") FuRun; FGRUN=1;;
		"fu_quit") FuQuit;;
	esac
}


########################################################################
## Option-helper
GetAllOptions() { 														## executed once
	if [ "$TESTMODE" != "y" ]; then
		echo "getting options from: fgfs --help --verbose"				## chgd to local
		local fgfs_verb="$(fgfs --help --verbose)"
	else
		local fgfs_verb="$(cat "$MY_REAL_PWD/$TESTOPTS")"				## chgd to local
	fi
	## ok, use this trick with IFS and awk to have named categories with items... ;)
	local tmpifs="$IFS"; IFS="@"										## chgd to local
	myc_groups=($(awk '$1 ~ /^--/ {gsub (/,$/, "", $1); \
									gsub(/@/, "€", $1); \
									gsub(/\|/, ",", $1); \
									print $1}; \
									$0 ~ /^[A-Z].*[:]$/ {print "@"$0}' \
				<<<"$fgfs_verb"))
	IFS="
"
	## now construct arrays in bashy way
	for sub_cg in "${myc_groups[@]}"; do
		if [ "$sub_cg" != "" ]; then
			NewGName="${sub_cg%%:*}"
			SECTIONNAMS[${#SECTIONNAMS[@]}]="$NewGName"
			NewGName=${NewGName// /}
			NewGName=${NewGName//\//}
			SECTIONS[${#SECTIONS[@]}]="$NewGName"
			sub_cg="${sub_cg//€/@}"
			tc_b=(${sub_cg#*:})
			SECTION_ENTRIES[${#SECTION_ENTRIES[@]}]="${tc_b[*]}"
		fi
	done
	IFS="$tmpifs";
}

##
CheckAllOptions() { 													## executed once
	TOG_MAN_OPT_CHECK=""
	for ((i=0; i<${#SECTIONS[@]}; i++)); do
		SecItem="${SECTIONS[$i]}"
		c_name="SECTION_ENTRIES[$i]"
		SecOpts=(${!c_name})
		for OptItem in "${SecOpts[@]}"; do
			if [ "${OptItem%%=*}" = "${1%%=*}" ]; then
				TOG_MAN_OPT_CHECK="y"
				echo "SecItem: [$SecItem]"
				echo "$OptItem : $1 - gefunden..."
				if [[ "${OptItem//[^=]/}" = "=" ]] \
						&& [[ "${1//[^=]/}" != "=" ]]; then
					echo "meinten Sie: [${OptItem}]...??? ja/nein - y/[KEY]: "
					read -n1 -s tog_correct_item
					if [ "$tog_correct_item" = "y" ]; then
						USE_OPTCODE="${OptItem}"
					fi
				fi
				break
			fi
		done
	done
	if [ "$TOG_MAN_OPT_CHECK" != "y" ]; then
		echo "nicht verfügbar..."
		break
	fi
	}

##
CheckAndSetOption() { 													## executed once
	tog_found_opt=""
	cloptit=0
	for loptitem in "${CURRENT_CONFIG[@]}"; do
		[ "${loptitem//*${1}*/}" = "" ] \
				&& chkitem=$(GetToggledBase "$1") \
				|| chkitem=""
		if [ "$chkitem" = "$1" ]; then
			tog_found_opt="y"
			echo "Option: [$1] gefunden ($loptitem)..."
			if [ "$TOG_OPTION" != "$loptitem" ]; then
				CURRENT_CONFIG[$cloptit]="$TOG_OPTION"
			else
				echo "gleiche Option bereits vorhanden, wird übersprungen..." ##"same Option found, not doing anything..."
			fi
		fi
		cloptit=$((cloptit + 1))
	done
	if [ "$tog_found_opt" != "y" ]; then
		CURRENT_CONFIG[${#CURRENT_CONFIG[@]}]="$TOG_OPTION"
	fi
}

GetToggledBase() {
	## get the --enabled --disabled argument-suffix (base)
	tmp_out="${1#--enable}"
	echo "${tmp_out#--disable}"
}

GetOtherSwitch() { 														## executed once
	## nur "--enable" oder "--disable" übergeben!
	switchlist=("--enable" "--disable")
	echo ${switchlist[@]//${1}/}
}

GetToggleSwitch() {
	for curr_str in "--enable" "--disable"; do
		if [ "$1" != "" ] && [ "${1/*${curr_str}*/}" = "" ]; then
			echo "${curr_str}"
			break
		fi
	done
}

DelOption() { 															## executed once
	## löscht eine option aus aktueller config
	CURRENT_CONFIG[$1]=""
	## config muss neu eingelesen werden, sonst bleibt der index "$1" leer erhalten
	CURRENT_CONFIG=(${CURRENT_CONFIG[@]})
}

SetOption() {
	## allgemeiner config-handler zur user-eingabe
	existing_equal=${1//[^=]/}											# check auf "=" (bleibt wenn vorhanden)
	if [ "$existing_equal" = "=" ]; then								# -"-
		equal_value=${1//[^=]*=/}										# string hinter dem "="
	else
		equal_value="null"
	fi
	if [ "$equal_value" != "null" ]; then								## wenn "=" gefunden:
		c_opt_code=${1//=[^=]*/}
		c_opt_code=${c_opt_code%=} 										## Versuch, Fehler bei Opt. eintippen xy=[leer]...
		if [ "$c_opt_code" = "--aircraft" ]; then
			SetAircraft
		else
			printf '%s\n' \
				"$MESS_SET_OPTION_HINT" \
				"Option [$c_opt_code] erwartet Wert ($equal_value): "
			read C_ARGUM
			if [ "$C_ARGUM" = "" ]; then
				C_ARGUM=$equal_value
			fi
		fi
		OPT_PART=$c_opt_code
		TOG_OPTION="$c_opt_code=$C_ARGUM"
	else																## wenn kein "=" gefunden:
		OPT_PART=$(GetToggledBase "$1")
		TOG_OPTION="$1"
	fi
	if [ "$OPT_PART" == "--aircraft" ] && [ -z "$C_ARGUM" ]; then
		echo "abgebrochen: [$OPT_PART$C_ARGUM]"
	else
		CheckAndSetOption "$OPT_PART"	## prüfen, ob Option bereits in CURRENT_CONFIG vorhanden (!) UND SETZEN (!):
		echo " wird übernommen..." 
	fi
}


########################################################################
## Aircraft-setting-helper
SetAircraft() { 														## executed once
	AskForAir
	C_ARGUM=$USE_AIRCODE
}

CheckAirCode() { 														## executed once
	out=1
	for dirachk in "${FOUND_AIRCRAFTS[@]}"; do
		if [ "$1" = "$dirachk" ]; then
			out=0
			break
		fi
	done
	echo $out
}

GetAllAircrafts() { 													## executed once
	if [ ! "${FOUND_AIRCRAFTS[0]}" ]; then
		if [ "$TESTMODE" != "y" ]; then
			local show_air=$(fgfs --show-aircrafts)
		else
			local show_air="$(cat "$MY_REAL_PWD/$TESTAIRC")"
		fi
	fi																	## (!) propably this 'fi' should be below at the end of this method, but could one add more paths in workflow???: check that

	##
	if [[ -e "$MY_REAL_PWD/$SCRIPT_GET_INPUT" ]] && [[ -e "$MY_REAL_PWD/$SCRIPT_EXT_AIR" ]]; then
		printf "weitere externe Pfade auswählen? ja/nein - y/[KEY]: ";
		read -sn1 tog_ext_airpath && echo "$tog_ext_airpath";
		if [ "$tog_ext_airpath" == "y" ]; then
			## New
			source "$MY_REAL_PWD/$SCRIPT_GET_INPUT" "-s";

			## local here again??
			local show_air="$show_air
$("$MY_REAL_PWD/$SCRIPT_EXT_AIR" "-s" "${AIRPATHS[@]}")";				## could use: var="string1"$'\n'"string2"

		fi
	fi

	## parse output of external print_aircrafts-script: skip lines with leading '#' and those with trailing ':'
	#FOUND_AIRCRAFTS=($(echo "$show_air" | awk '$0 !~ /:$/ {print $1}'))
	FOUND_AIRCRAFTS=($(echo "$show_air" | awk '$0 !~ /:$/ && $0 !~ /^#/ {print $1}'))
}

## not used
##
#Get_Usr_Input() {
#	[ -e "$MY_REAL_PWD/$SCRIPT_GET_INPUT" ] \
#		&& { \
#			echo "hurray, starting $SCRIPT_GET_INPUT..."; \
#			source "$MY_REAL_PWD/$SCRIPT_GET_INPUT" "-s"; \
#			USR_AIRPATHS=("${AIRPATHS[@]}"); } \
#		|| echo "oh no, $MY_REAL_PWD/$SCRIPT_GET_INPUT not found..."
#}
##

##
AskForAir() { 															## executed once
	unset chkdone USE_AIRCODE tog_direkt tog_show_list
	GetAllAircrafts
	echo "Kürzel direkt eingeben? y/[KEY] - (yes/no): "
	read -n1 -s tog_direkt
	if [ "$tog_direkt" = "y" ]; then
		echo "Liste anzeigen? "
		read -n1 -s tog_show_list
		if [ "$tog_show_list" = "y" ]; then
			MenuShow "FOUND_AIRCRAFTS[@]" "Luftfahrzeuge" "" $CNT_ROUND
		fi

		while [ "$chkdone" != "y" ]; do
			echo -ne "Geben sie das Kürzel ein: "
			read -e USE_AIRCODE
			if [ $(CheckAirCode "$USE_AIRCODE") -eq 0 ]; then
				chkdone="y"
				break
			else
				echo -e "$USE_AIRCODE $MESS_ASK_AIR_HINT\n"\
						"->trotzdem dieses Flugzeug übernehmen? (y/[KEY])"\
						"- (yes/no): "
				read -n1 -s tog_force_aircode
				if [ "$tog_force_aircode" = "y" ]; then
					echo "ok"
					chkdone="y"
					break
				fi
			fi
		done

	else
		MenuChooseEnter "FOUND_AIRCRAFTS[@]" "Flugzeuge"
		if [ "$CHOSEN" != "" ]; then
			USE_AIRCODE=$CHOSEN
			TOG_QUIT="y"
		fi
		echo "CHOSEN: $CHOSEN; USE_AIRCODE: $USE_AIRCODE"
	fi
}


########################################################################
## Fu is Core...

## New
FuCheckNGetConf() {
	if [ -f "$CONFIGFILE" ]; then
		echo "Konfiguration [$CONFIGFILE] gefunden..."
		FuGetConf
	else
		echo "keine Konfiguration gefunden..."
	fi
}
##


FuGetConf() {
	local showmyconf=($(sed -e '/^$/d' "$CONFIGFILE" | sed '$!d'))		## chgd to local
	echo "[${showmyconf[@]}]"

	echo -ne "übernehmen? ja/nein - y/[KEY]: "
	read -n1 -s togdef

	if [ "$togdef" = "y" ]; then
		## hier ist immer 'fgfs' vorangestellt, wurde ja so in die $CONFIGFILE geschrieben und muss daher wieder raus... (!)
		## ACHTUNG: daher muss der workaround in FuChgRemOpt wieder rausgenommen werden!!!
		#CURRENT_CONFIG=(${showmyconf[@]})

		CURRENT_CONFIG=(${showmyconf[@]:1})
		# sonst:
		#[ "${showmyconf[0]}" == "fgfs" ] && showmyconf=("${showmyconf[@]:1}")
		#CURRENT_CONFIG=(${showmyconf[@]})

		echo "übernommen..."
	else
		CURRENT_CONFIG=()
		echo "nicht übernommen..."
	fi
	}

FuAddOpt() {
	unset USE_AIRCODE TOG_MAN_OPT_CHECK
	if [ ! "${SECTIONNAMS[0]}" ]; then
		GetAllOptions
	fi
	if [ "$1" = "man" ]; then
		echo "$MESS_ADD_OPT_HINT"
		read -n1 -s OPTCHK
		echo -n "Option eintippen: "
		if [ "$OPTCHK" = "y" ]; then
			while [ "$TOG_MAN_OPT_CHECK" != "y" ]; do ##wtf..
				read USE_OPTCODE
				CheckAllOptions "$USE_OPTCODE"
			done
			if [ "$TOG_MAN_OPT_CHECK" = "y" ]; then	##..wtf
				SetOption "$USE_OPTCODE"
			else
				echo "wtf... should not occure?"
			fi
		else
			echo "(!) Option wird nicht überprüft!"
			read USE_OPTCODE
			SetOption "$USE_OPTCODE"
		fi
	else
		MenuChooseEnter "SECTIONNAMS[@]" "Kategorien"

		while [ "$TOG_QUIT" != "y" ]; do
			local tmpifs="$IFS"; IFS=$'\n'
			C_CG=(${SECTION_ENTRIES[$TOG_GROUP_NUM]})
			IFS="$tmpifs"
			MenuChooseEnter "C_CG[@]" "${SECTIONNAMS[$TOG_GROUP_NUM]}"
			if [ "$CHOSEN" != "" ]; then
				SetOption "$CHOSEN"
				TOG_QUIT="y"
			fi
		done
	fi
}

##
FuChgRemOpt() {
## Removed workaround, see: FuGetConf
	#C_CONFIG=("${CURRENT_CONFIG[@]:1}")
	#MenuChooseEnter "C_CONFIG[@]" "Optionen"							## added :1 to cut "fgfs" (is in CURRENT_CONFIG)

	MenuChooseEnter "CURRENT_CONFIG[@]" "Optionen"						
##
	if [ "$CHOSEN" != "" ]; then
		if [ "$1" = "rem" ]; then
			DelOption "$TOG_GROUP_NUM"
		else
			echo "ok, ändern: $CHOSEN"
			if [ "$(GetToggleSwitch $CHOSEN)" != "" ]; then
				OPT_PART=$(GetToggledBase "$CHOSEN")
				SetOption "$(GetOtherSwitch $(GetToggleSwitch \"$CHOSEN\"))$OPT_PART"
			else
				SetOption "$CHOSEN"
			fi
		fi
		TOG_QUIT="y"
	else
		echo "\$CHOSEN: leerer string... ($CHOSEN)"
	fi
}

##
FuSavOpt() {
	echo "speichere Konfiguration..."
	checkconf=$(sed '$!d' "$CONFIGFILE")
	myconfstr="${CURRENT_CONFIG[@]}"
	if [ "$checkconf" != "$myconfstr" ]; then
		echo "## added $(date) - 1" >> "$CONFIGFILE"
		echo ${CURRENT_CONFIG[@]} >> "$CONFIGFILE"
	else
		local relacnt=$(sed '$d' "$CONFIGFILE" | sed '$!d' | awk '{print $NF}')		## chgd to local
		## overwrite existing $CONFIGFILE, counting up:
		## overwriting existing $CONFIGFILE without last used config entry
		sed '$!N;$D' -i "$CONFIGFILE"
		## adding last used config, counting up
		echo "## added $(date) - $((relacnt+1))" >> "$CONFIGFILE"
		echo ${CURRENT_CONFIG[@]} >> "$CONFIGFILE"
	fi
}

FuRun() {
	FuSavOpt
	confstr="${CURRENT_CONFIG[@]}"
	$TERM -e "{ echo \"${confstr}\";fgfs ${confstr}; }" &
	sleep 1 ## da das skript beendet wird, wenn FuRun ausgeführt wurde 
			## (FGRUN=1), muss kurz gewartet werden, sonst bricht der 
			## prozess (terminal, in dem fgfs gestartet wird) ab! (wtf?)
}

FuQuit() {
	echo "ok, beenden" && exit 0
}


######
## Fu-Core, kern des pudels
FuMain() {
	main_menu_text=("Konfiguration bearbeiten" \
				"Option hinzufügen" \
				"FlightGear ausführen" \
				"beenden")
	main_menu_actions=("FuActionHelper fu_conf" \
				"FuActionHelper fu_add" \
				"FuActionHelper fu_run" \
				"FuActionHelper fu_quit")
	conf_sub_text=("letzte Konfiguration einlesen" \
				"Option ändern" \
				"Option löschen" \
				"Konfiguration sichern")
## New: FuCheckNGetConf
	conf_sub_actions=("FuCheckNGetConf" \
				"FuChgRemOpt" \
				"FuChgRemOpt rem" \
				"FuSavOpt")
##
	add_sub_text=("Option direkt eingeben" \
				"Kategorie durchsuchen")
	add_sub_actions=("FuAddOpt man" \
				"FuAddOpt")

	## check if fgfs is installed
	#printf '%s ' "suche Befehl fgfs:" ## "checking for command fgfs: "
	CheckCommandExists "fgfs" \
			&& printf '%s\n' "flightgear installiert" \
			|| { TESTMODE="y"; echo -e "$MESS_NO_FGFS"; }

	FGRUN=0
	#printf '%s\n' "suche Arbeitspfad... ($0)"
	GetMyPaths "$0" ## && printf '[%s]\n' "$MY_REAL_PWD"
	CONFIGFILE="$MY_REAL_PWD/$CONFIGFILE"

	FuCheckNGetConf

	SECTION_ENTRIES=()
	CNT_ROUND=0

	while [ "$FGRUN" -eq 0 ]; do
		PrintConfig

		GetCurPosition && cur_pos0="${CUR_ROW%;*}"

		FuActionHelper "fu_main"

		while [ "$FGRUN" -eq 0 ]; do
			if [ -z "$ACTION" ]; then
				break
			else

				tput cup "$(($cur_pos0-1))" 0 && tput ed

				exec_action="$ACTION"									## added quotes...
				ACTION=""

				echo " excuting now: $exec_action"
				$exec_action
			fi
			CNT_ROUND=$((CNT_ROUND + 1))
			done
	done
	echo "flightgear gestartet, Skript wird beendet"
}


########################################################################

## Hauptteil ###########################################################

## Ini-Variablen (you may want to change configfile) ###################
## these files are needed to add external airpaths, but can be used to print-nice your external aircrafts as standalone...
SCRIPT_EXT_AIR="fgfs_ext_print_air.sh"
SCRIPT_GET_INPUT="fgfs_ext_get_airpaths.sh"

##
MY_FAV_TERM="lxterminal"												## nicht so schön, muss JEDER INDIVIDUELL anpassen... (!) ...war schon mal automatisiert, siehe alte version...

CheckCommandExists "$MY_FAV_TERM" \
	&& MY_FAV_TERM="lxterminal" \
	|| MY_FAV_TERM="xterm"
##

CONFIGFILE="fgfs-xmenu_conf.txt"

TESTMODE="" ## (!) wird automatisch "y" wenn fgfs nicht gefunden wird
			## (dann werden die folgenden Dateien benötigt)
TESTOPTS="fgfs_help_verbose_output.txt"
TESTAIRC="fgfs_show_aircrafts_output.txt"

MESS_NO_FGFS="flightgear nicht gefunden, dieses Skript kann getestet \
werden mit der Ausgabe der Befehle: \"fgfs --help --verbose\" und \
optional: \"fgfs --show--aircraft\", die an einem Computer mit \
flightgear in Dateien gespeichert wurden"

MESS_NO_SHELL="$0: nicht in einer sichtbaren Shell\ngestartet, bitte \
in einem Terminal(/-Emulator) starten..."

MESS_SET_OPTION_HINT="bitte Wert eingeben (wenn bereits ein Wert (in \
Klammern) verfügbar, kann dieser mit ENTER bestätigt \
werden)!"

MESS_ASK_AIR_HINT="nicht gefunden,\n(fgfs --show-aircraft erkennt keine \
zusätzlichen aircraft-pfade, auch nicht bei vorangestellter \
pfad-option...)"

MESS_ADD_OPT_HINT="Option überprüfen (soll eine Property-Option mittels \
\"prop:path/arg=[value]\" eingegeben werden, mit \"no\" antworten!)? \
y/[KEY] - yes/no: "

MESS_NO_TEST_FILES="nicht alle Testdateien gefunden..."

##will be set (global):
# MY_REAL_PWD, MY_CURRENT_CONFIG, TESTMODE, TESTOPTS, SECTIONNAMS, 
# SECTIONS, SECTION_ENTRIES, ...


## kern des pudels
########################################################################
my_host=$(GetPidHostEmulator $$)
echo "scriptname: ${0#./}, my_host: [$my_host]"

## skript startet sich neu in einer sichtbaren shell (pts/[num]),
## wenn es nicht in einer solchen gestartet wurde...
## (könnte auch direkt nach der pts/[num]-spalte gucken siehe altes skript)

#if [ "$my_host" == "init" ]; then ## vermeintlich keine sichtb. shell (s.o.)
if [ "$my_host" != "sh" ] && [ "$my_host" != "bash" ]; then ## vermeintlich keine sichtb. shell (s.o.)
	#zenity --info --text "my_host: $my_host, killing myself ($BASHPID)\n\and reloading:\nxterm -e \"{ \${0}; \?}\""
	## tell user that script should be started within a viewable terminal-console
	CheckCommandExists "zenity" \
		&& { export NO_AT_BRIDGE=1; \
			zenity --info --text "my_host: [$my_host], killing myself (pid $BASHPID)\nand reloading:\nxterm -e \"{ \${0}; \?}\""; }

	case $MY_FAV_TERM in
		"lxterminal" ) \
			lxterminal -l -e "${0} || { echo exiting; sleep 2; }" &;;
		* ) \
			xterm -e "{ ${0} || { echo exiting; sleep 2; }; }" &;;
	esac

	sleep 1
	kill $BASHPID
	#exit 1

else
	## started within a terminal, run...
	FuMain
fi
