#!/bin/bash


# Author           : Mateusz Małecki ( alternatywny.rudy@gmail.com )
# Created On       : 24.05.2018
# Last Modified By : Mateusz Małecki ( alternatywny.rudy@gmail.com )
# Last Modified On : 28.05.2018
# Version          : 1.02
#
# Description      :
# Kalendarz z organizajcą plików (archiwizacja, kompresja)
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)


while getopts hv OPT; do
	case $OPT in
		h) 
			echo "Help: kalendarz is basic files organization calendar. It gives user options of adding new event, compressing event or group of events, deleting events and adding compressed events. It also has archivization system. Just follow zenity informations and it all gonna be good";;
		v) 
			echo "Author: Mateusz Małecki (alternatywny.rudy@gmail.com)"
			echo "Version: 1.02"
			echo "Last modified: 27.05.2018";;
		*)
			echo "Nie wybrano żadnej opcji";;
	esac
done
IFS=$'\t\n'
if [ -e konfiguracja.rc ]
then
	{ read KATALOG; read CZAS; } <konfiguracja.rc
else
	ODP=`zenity --file-selection --directory --title="Wybierz katalog na pliki programu"`
	if [ $? -eq 0 ]
	then
		CZAS=`zenity --forms --title="Konfiguracja" --text="Wprowadź dane konfiguracyjne." --separator="," --add-entry="Ilość dni po minięciu daty wydarzenia, po której ma zostać zarchiwizowane (domyślnie 7): "`
	
		if [ $? -eq 0 ]
		then
			if [ $CZAS -z ] &> /dev/null
			then
				CZAS=7;
			fi
			printf "%d" "$CZAS" &> /dev/null
			if [[ $? -ne 0 ]] ; then
    				echo "$CZAS nie jest liczba."
    				zenity --error --text "Nie zaakceptowano wyrażenia nienumerycznego."
				exit
			else
				KATALOG="$ODP/kalendarz"
				mkdir $KATALOG
				echo $KATALOG > konfiguracja.rc
				echo $CZAS >> konfiguracja.rc
			fi
		fi
	fi
fi

if [ -e konfiguracja.rc ]
then
	echo "Znaleziono plik konfiguracyjny"
else
	echo "Nie znaleziono pliku konfiguracyjnego"
	exit
fi

#obrót daty pozwalający porównywać je jak liczby
inwersja_daty(){
	DATA_DZIEN=$(echo $DATA_DO_INWERSJI | cut -d '.' -f 1)
	DATA_MIESIAC=$(echo $DATA_DO_INWERSJI | cut -d '.' -f 2)
	DATA_ROK=$(echo $DATA_DO_INWERSJI | cut -d '.' -f 3)
	
	DATA_PO_INWERSJI="$DATA_ROK$DATA_MIESIAC$DATA_DZIEN"
}

#archiwizowanie starych wydarzeń
DATA=$(date --date="$CZAS days ago" +%Y%m%d)
I=1
K=1
unset LISTA_DAT[*]
for ELEMENT in $(cat konfiguracja.rc)
do
if [ $I -gt 2 ]
then
	DATA_STARA=$(echo $ELEMENT | cut -d ',' -f 1)
	DATA_DO_INWERSJI=$DATA_STARA
	inwersja_daty
	DATA_STARA_PO_INWERSJI=$DATA_PO_INWERSJI
	if [ $DATA_STARA_PO_INWERSJI -lt $DATA ]
	then
		BYL="N"
		for SPR in ${LISTA_DAT[@]}
		do
			if [ "$SPR" = "$DATA_STARA" ]
			then
				BYL="T"
			fi
		done
		if [ "$BYL" = "N" ]
		then
			LISTA_DAT[$K]=$DATA_STARA
			NAZWA_STARA=$(echo $ELEMENT | cut -d ',' -f 2)
			TMP="/tmp/lista_skompresowanych_wydarzen.txt"
			echo "" > $TMP
			grep "$DATA_STARA" konfiguracja.rc >> $TMP
			mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
			mv "$KATALOG/$DATA_STARA" "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
			cp $TMP "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
			if [ -d "$KATALOG/zarchiwizowane_pliki" ]
			then
				tar -cf "$KATALOG/zarchiwizowane_pliki/$DATA_STARA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
			else
				mkdir "$KATALOG/zarchiwizowane_pliki"
				tar -cf "$KATALOG/zarchiwizowane_pliki/$DATA_STARA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
			fi
			rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
			sed -i "/$DATA_STARA,/d" konfiguracja.rc
		fi
	fi
fi
I=`expr $I + 1`
done

#poszczególne menu
MENU=("Dodaj wydarzenie" "Wyświetl wydarzenia z przedziału czasu" "Wyświetl wszystkie wydarzenia" "Skompresuj wydarzenia" "Dodaj skompresowane wydarzenia" "Zmień dane konfiguracyjne")
MENU_AKCJI=("Otwórz katalog wydarzenia" "Usuń wydarzenie" "Skompresuj wydarzenie")

#główna pętla
while true
do
	#wyświetlanie menu głównego
	ODP=`zenity --list --column=Menu "${MENU[@]}" --height 300 --width 300 --cancel-label="Zakończ program"`
	if [[ $? -eq 1 ]]; then
	    echo "Program zakończony"
	    break
	fi
	#obsługa menu głównego
	case "$ODP" in
		#dodawanie wydarzenia
		"${MENU[0]}" )
			while true
			do
				TRESC=`zenity --forms --title="Dodaj wydarzenie" --text="Wprowadź informacje o wydarzeniu" --separator="," --cancel-label="menu główne" --ok-label="Dodaj" --add-calendar="Data" --add-entry="Nazwa wydarzenia" --add-entry="Opis wydarzenia"`
				if [[ $? -eq 1 ]]; then
	    				echo "Powrót do menu głównego"
					break
				else
					DATA=$(echo $TRESC | cut -d ',' -f 1)
					NAZWA=$(echo $TRESC | cut -d ',' -f 2)
					OPIS=$(echo $TRESC | cut -d ',' -f 3)
					if [ "$NAZWA" != "" ]
					then
						KATALOG_Z_WYDARZENIEM="$KATALOG/$DATA/$NAZWA"
						KATALOG_TEJ_DATY="$KATALOG/$DATA"
						if [ -d $KATALOG_Z_WYDARZENIEM ]
						then
							zenity --error --text="Takie wydarzenie juz istnieje"
							xdg-open $KATALOG_Z_WYDARZENIEM
						else
							if [ -d $KATALOG_TEJ_DATY ]
							then
								mkdir $KATALOG_Z_WYDARZENIEM
								echo $OPIS > "$KATALOG_Z_WYDARZENIEM/opis.txt"
								xdg-open $KATALOG_Z_WYDARZENIEM
							else
								mkdir $KATALOG_TEJ_DATY
								mkdir $KATALOG_Z_WYDARZENIEM
								echo $OPIS > "$KATALOG_Z_WYDARZENIEM/opis.txt"
								xdg-open $KATALOG_Z_WYDARZENIEM
							fi
							echo "$DATA,$NAZWA" >> konfiguracja.rc
							break
						fi
					else
						zenity --error --text="Pole nazwy nie może być puste"
					fi
				fi
			done;;
		#wyświetlanie wydarzeń z przedziału czasu
		"${MENU[1]}" )
			WYBRANO="N"
			while [ "$WYBRANO" != "T" ]
			do
			#wyświetlanie wyboru zakresu czasu
			TMP="/tmp/zakres_do_wyswietlenia.$$"
			zenity --forms --title="Wybieranie zakresu" --text="Wybierz zakres czasu do pokazania wydarzeń" --separator="," --cancel-label="menu główne" --ok-label="Zatwierdź" --add-calendar="Data od" --add-calendar="Data do" > $TMP
			#obsługa wyboru zakresu
			if [[ $? -eq 1 ]]; then
	    			echo "Powrót do menu głównego"
				break
			else
				DATA_OD=$(cut $TMP -d ',' -f 1)
				DATA_DO=$(cut $TMP -d ',' -f 2)
				DATA_DO_INWERSJI=$DATA_OD
				inwersja_daty
				DATA_OD=$DATA_PO_INWERSJI
				DATA_DO_INWERSJI=$DATA_DO
				inwersja_daty
				DATA_DO=$DATA_PO_INWERSJI
				if [ $DATA_OD -gt $DATA_DO ]
				then
					zenity --error --text="Data od musi być wcześniejsza od daty do"
				else
					while [ "$WYBRANO" != "T" ]
					do
					#znajdowanie odpowiednich wydarzeń
					unset MENU_WYBORU_WYDARZENIA[*]
					unset DATY_WYBORU_WYDARZENIA[*]
					unset NAZWY_WYBORU_WYDARZENIA[*]
					# inicjujemy zmienną mówiącą o numerze wersu
					K=1
					I=1
					for WERS in $(cat konfiguracja.rc)
					do
					if [ $K -gt 2 ]
					then
						DATA=$(echo $WERS | cut -d ',' -f 1)
						DATA_DO_INWERSJI=$DATA
						inwersja_daty
						DATA=$DATA_PO_INWERSJI
						if [[ $DATA -ge $DATA_OD && $DATA -le $DATA_DO ]]
						then
							NAZWY_WYBORU_WYDARZENIA[$I]=$(echo $WERS | cut -d ',' -f 2);
							DATY_WYBORU_WYDARZENIA[$I]=$(echo $WERS | cut -d ',' -f 1);
							MENU_WYBORU_WYDARZENIA[$I]=$WERS
							I=`expr $I + 1`
						fi
					fi
					K=`expr $K + 1`
					done
					#wyświetlanie wyboru wydarzeń
					ODP=`zenity --list --column=Menu "${MENU_WYBORU_WYDARZENIA[@]}" --height 500 --width 300 --cancel-label="Wybór dat" --ok-label="Wybierz wydarzenie"`
					if [[ $? -eq 1 ]]; then
	    					echo "Powrót do wyboru dat"
						break
					else
						#wyświetlanie opcji
						I=1
						DATA=""
						for OPCJA in ${MENU_WYBORU_WYDARZENIA[@]}; do
						if [ "$ODP" = "$OPCJA" ]
						then
							DATA=${DATY_WYBORU_WYDARZENIA[$I]}
							NAZWA=${NAZWY_WYBORU_WYDARZENIA[$I]}
						fi
						I=`expr $I + 1`
						done
						if [ $DATA -z ]
						then
							zenity --error --text="Nie wybrano wydarzenia"
						else
							while true
							do
							KATALOG_Z_WYDARZENIEM="$KATALOG/$DATA/$NAZWA"
							ODP=`zenity --list --column=Menu "${MENU_AKCJI[@]}" --height 500 --width 300 --cancel-label="Wybór dat" --ok-label="Zatwierdź akcje" --cancel-label="Wybór wydarzenia"`
							#obsługa opcji
							if [[ $? -eq 1 ]]; then
	    							echo "Powrót do wyboru wydarzenia"
								break
							else
								case "$ODP" in
									"${MENU_AKCJI[0]}" )
										xdg-open $KATALOG_Z_WYDARZENIEM
										WYBRANO="T"
										break;;
									"${MENU_AKCJI[1]}" )
										rm -r $KATALOG_Z_WYDARZENIEM
										rmdir "$KATALOG/$DATA"
										sed -i "/$DATA,$NAZWA/d" konfiguracja.rc
										WYBRANO="T"
										break;;
									"${MENU_AKCJI[2]}" )
										TMP="/tmp/lista_skompresowanych_wydarzen.txt"
										echo "" > $TMP
										echo "$DATA,$NAZWA" >> $TMP
										mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
										mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA"
										cp -r "$KATALOG/$DATA/$NAZWA" "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA/"
										cp $TMP "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
										if [ -d "$KATALOG/skompresowane_pliki" ]
										then
										tar -cf "$KATALOG/skompresowane_pliki/$DATA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
										else
										mkdir "$KATALOG/skompresowane_pliki"
										tar -cf "$KATALOG/skompresowane_pliki/$DATA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
										fi
										rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
										xdg-open "$KATALOG/skompresowane_pliki"
										WYBRANO="T"
										break;;
									*) zenity --error --text="Nie wybrano opcji";;
								esac
							fi
							done
						fi
					fi
					done
				fi
			fi
			done;;
		#wyświetlanie wszystkich wydarzeń
		"${MENU[2]}" )
			WYBRANO="N"
			#czyszczenie tablic na wypadek wielokrotnego użytku opcji
			unset MENU_WYBORU_WYDARZENIA[*]
			unset DATY_WYBORU_WYDARZENIA[*]
			unset NAZWY_WYBORU_WYDARZENIA[*]
			#ustalenie zmiennych iteracyjnych
			I=1
			K=1
			for WERS in $(cat konfiguracja.rc)
			do
			if [ $K -gt 2 ]
			then
				#utworzenie menu i odpowiednich tablic
				NAZWY_WYBORU_WYDARZENIA[$I]=$(echo $WERS | cut -d ',' -f 2);
				DATY_WYBORU_WYDARZENIA[$I]=$(echo $WERS | cut -d ',' -f 1);
				MENU_WYBORU_WYDARZENIA[$I]=$WERS
				I=`expr $I + 1`
			fi
			K=`expr $K + 1`
			done
			while [ "$WYBRANO" != "T" ]
			do
				#wyświetlenie wyboru wydarzenia
				ODP=`zenity --list --column=Menu "${MENU_WYBORU_WYDARZENIA[@]}" --height 500 --width 300 --cancel-label="Menu główne" --ok-label="Zobacz wydarzenie"`
				if [[ $? -eq 1 ]]; then
	    				echo "Powrót do menu głównego"
					break
				else
					#otwieranie wydarzenia
					I=1
					DATA=""
					for OPCJA in ${MENU_WYBORU_WYDARZENIA[@]}; do
					if [ "$ODP" = "$OPCJA" ]
					then
						DATA=${DATY_WYBORU_WYDARZENIA[$I]}
						NAZWA=${NAZWY_WYBORU_WYDARZENIA[$I]}
					fi
					I=`expr $I + 1`
					done
					if [ $DATA -z ]
					then
						zenity --error --text="Nie wybrano wydarzenia"
					else
						while true
						do
						KATALOG_Z_WYDARZENIEM="$KATALOG/$DATA/$NAZWA"
						ODP=`zenity --list --column=Menu "${MENU_AKCJI[@]}" --height 500 --width 300 --cancel-label="Wybór dat" --ok-label="Zatwierdź akcje" --cancel-label="Wybór wydarzenia"`
						#obsługa opcji
						if [[ $? -eq 1 ]]; then
	    						echo "Powrót do wyboru wydarzenia"
							break
						else
							case "$ODP" in
								"${MENU_AKCJI[0]}" )
									xdg-open $KATALOG_Z_WYDARZENIEM
									WYBRANO="T"
									break;;
								"${MENU_AKCJI[1]}" )
									rm -r $KATALOG_Z_WYDARZENIEM
									rmdir "$KATALOG/$DATA"
									sed -i "/$DATA,$NAZWA/d" konfiguracja.rc
									WYBRANO="T"
									break;;
								"${MENU_AKCJI[2]}" )
									TMP="/tmp/lista_skompresowanych_wydarzen.txt"
									echo "" > $TMP
									echo "$DATA,$NAZWA" >> $TMP
									mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
									mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA"
									cp -r "$KATALOG/$DATA/$NAZWA" "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA/"
									cp $TMP "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
									if [ -d "$KATALOG/skompresowane_pliki" ]
									then
									tar -cf "$KATALOG/skompresowane_pliki/$DATA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
									else
									mkdir "$KATALOG/skompresowane_pliki"
									tar -cf "$KATALOG/skompresowane_pliki/$DATA.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
									fi
									rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
									xdg-open "$KATALOG/skompresowane_pliki"
									WYBRANO="T"
									break;;
								*) zenity --error --text="Nie wybrano opcji";;
							esac
						fi
						done
					fi
				fi
			done;;
		"${MENU[3]}" )
			while true
			do
			#wyświetlanie wyboru zakresu
			TMP="/tmp/zakres_do_kompresji.$$"
			zenity --forms --title="Wybieranie zakresu" --text="Wybierz zakres czasu do pokazania wydarzeń" --separator="," --cancel-label="menu główne" --ok-label="Zatwierdź" --add-calendar="Data od" --add-calendar="Data do" > $TMP
			#obsługa wyboru zakresu
			if [[ $? -eq 1 ]]; then
	    			echo "Powrót do menu głównego"
				break
			else
				DATA_OD=$(cut $TMP -d ',' -f 1)
				DATA_DO=$(cut $TMP -d ',' -f 2)
				DATA_DO_INWERSJI=$DATA_OD
				inwersja_daty
				DATA_OD_PO_INWERSJI=$DATA_PO_INWERSJI
				DATA_DO_INWERSJI=$DATA_DO
				inwersja_daty
				DATA_DO_PO_INWERSJI=$DATA_PO_INWERSJI
				if [ $DATA_OD_PO_INWERSJI -gt $DATA_DO_PO_INWERSJI ]
				then
					zenity --error --text="Data od musi być wcześniejsza od daty do"
				else
					#znajdowanie odpowiednich wydarzeń
					TMP="/tmp/lista_skompresowanych_wydarzen.txt"
					echo "" > $TMP
					unset KATALOGI_DO_SKOMPRESOWANIA[*]
					# inicjujemy zmienną mówiącą o numerze wersu
					I=1
					K=1
					for WERS in $(cat konfiguracja.rc)
					do
					if [ $K -gt 2 ]
					then
						DATA=$(echo $WERS | cut -d ',' -f 1)
						DATA_DO_INWERSJI=$DATA
						inwersja_daty
						DATA=$DATA_PO_INWERSJI
						if [[ $DATA -ge $DATA_OD_PO_INWERSJI && $DATA -le $DATA_DO_PO_INWERSJI ]]
						then
							echo $WERS >> $TMP
							KATALOGI_DO_SKOMPRESOWANIA[$I]="$KATALOG/`echo $WERS | cut -d ',' -f 1`"
							I=`expr $I + 1`
						fi
					fi
					K=`expr $K + 1`
					done
					#kompresja wydarzeń
					mkdir "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
					for ELEMENT in ${KATALOGI_DO_SKOMPRESOWANIA[@]}; do
					cp -r $ELEMENT "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
					done
					cp $TMP "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/"
					if [ -d "$KATALOG/skompresowane_pliki" ]
					then
						tar -cf "$KATALOG/skompresowane_pliki/$DATA_OD-$DATA_DO.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
					else
						mkdir "$KATALOG/skompresowane_pliki"
						tar -cf "$KATALOG/skompresowane_pliki/$DATA_OD-$DATA_DO.tar" -C "$KATALOG" "WYDARZENIA_DO_SKOMPRESOWANIA"
					fi
					rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
					xdg-open "$KATALOG/skompresowane_pliki"
					break
				fi
			fi
			done;;
		"${MENU[4]}" )
			#wyświetlanie wyboru pliku
			PLIK=`zenity --file-selection --title="Wybierz plik do rozpakowania"`
			if [[ $? -eq 1 ]]; then
	    			echo "Powrót do menu głównego"
				break
			else
				#obsługa wypakowania pliku
				tar -xf $PLIK -C $KATALOG
				if [ -e "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/lista_skompresowanych_wydarzen.txt" ]
				then
					I=1
					for WERS in $(cat "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/lista_skompresowanych_wydarzen.txt")
					do
						NAZWA_NOWA=$(echo $WERS | cut -d ',' -f 2);
						DATA_NOWA=$(echo $WERS | cut -d ',' -f 1);
						WERS_NOWY=$WERS
						BYL="N"
						#sprawdzanie czy takie wydarzenie już istnieje
						for WERS_STARY in $(cat konfiguracja.rc)
						do
						if [ "$WERS_STARY" = "$WERS_NOWY" ]
						then
							#wyświetlanie i obsługa decyzji użytkownika w sprawie powtarzających się wydarzeń
							zenity --question --title="Zbieżność nazw" --text="Plik $WERS_NOWY już istnieje, chcesz go zastąpić czy pominąć wypakowanie tego pliku?" --cancel-label="Pomiń" --ok-label="Zastąp"
							if [[ $? -eq 1 ]]; then
	    							BYL="T"
								break
							else
								rm -r "$KATALOG/$DATA_NOWA/$NAZWA_NOWA"
								mv "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA_NOWA/$NAZWA_NOWA" "$KATALOG/$DATA_NOWA/"
								BYL="T"
								break
							fi
						fi
						done
						if [ "$BYL" = "N" ]
						then
							echo $WERS_NOWY >> konfiguracja.rc
							if [ -d "$KATALOG/$DATA_NOWA" ]
							then
								mv "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA_NOWA/$NAZWA_NOWA" "$KATALOG/$DATA_NOWA/"
							else
								mkdir "$KATALOG/$DATA_NOWA"
								mv "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA/$DATA_NOWA/$NAZWA_NOWA" "$KATALOG/$DATA_NOWA/"
							fi
						fi
					I=`expr $I + 1`
					done
					rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
				else
					zenity --error --text="Podany plik nie jest kompatybilny z programem"
					rm -r "$KATALOG/WYDARZENIA_DO_SKOMPRESOWANIA"
				fi
			fi;;
		"${MENU[5]}" )
			#wyświetlanie zmian danych konfiguracyjnych
			while true
			do
				ODP=`zenity --file-selection --directory --title="Wybierz katalog na pliki programu"`
				if [ $? -eq 1 ]
				then
					echo "Powrót do menu głównego"
					break
				else
					CZAS_NOWY=`zenity --forms --title="Konfiguracja" --cancel-label="Wybór katalogu" --text="Wprowadź dane konfiguracyjne." --separator="," --add-entry="Ilość dni po minięciu daty wydarzenia, po której ma zostać zarchiwizowane (domyślnie 7, uprzednio $CZAS): "`
	
					if [ $? -eq 1 ]
					then
						echo "Powrót do wyboru katalogu docelowego"
					else
						if [ $CZAS_NOWY -z ] &> /dev/null
						then
							CZAS_NOWY=7
						fi
						printf "%d" "$CZAS_NOWY" &> /dev/null
						if [[ $? -ne 0 ]] ; then
    							echo "$CZAS nie jest liczba."
    							zenity --error --text "Nie zaakceptowano wyrażenia nienumerycznego."
							break
						else
							KATALOG_NOWY="$ODP/kalendarz"
							TMP="/tmp/konf.$$"
							sed '1,2d' konfiguracja.rc > $TMP

							echo $KATALOG_NOWY > konfiguracja.rc
							echo $CZAS_NOWY >> konfiguracja.rc
							cat $TMP >> konfiguracja.rc
							if [ "$KATALOG_NOWY" != "$KATALOG" ]
							then
								zenity --question --title="Zmiana katalogu" --text="Czy chcesz aby pliki zostały przeniesione do nowego katalogu ?" --cancel-label="Nie" --ok-label="Tak"
								if [ $? -eq 1 ]
								then
									echo "Powrót do menu głównego"
									echo $KATALOG_NOWY > konfiguracja.rc
									echo $CZAS_NOWY >> konfiguracja.rc
									rm -r "$KATALOG"
									mkdir "$KATALOG_NOWY"
									KATALOG=$KATALOG_NOWY
									CZAS=$CZAS_NOWY
									break
								else
									mv "$KATALOG" "$ODP/"
									KATALOG=$KATALOG_NOWY
									CZAS=$CZAS_NOWY
									break
								fi
							fi
						fi
					fi
				fi
			done;;
		*) zenity --error --text="Nie wybrano opcji";;
	esac
done










