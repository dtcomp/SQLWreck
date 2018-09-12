#!/bin/bash

UM_SCAN_LINES=5
ROUTINE_DEFS=''

for f in $*;
do

	CMODULE=$( head -1 "$f" | grep -im2 -- '^--.*Module:' | sed -e 's/^-- Module:\([^ \t]*\)[ \t]*$/\1./i' ) 
	UMODULE=$( head -$UM_SCAN_LINES "$f" | grep -Ei '^[^-]*[ \t]*use[ \t][`]?[^ \t`]+[`]?[ ]*[;]?.*$' | sed -e 's/use[ \t]\+`\([^ \t`]\+\)`;/\1/' ) 

	ROUTINES=$( grep -inH ',[[:space:]]*delim VARCHAR(1)' "$f" | sed -r -e 's/^([^ \t]+:[0-9]+)[: \t]?CREATE[ \t]+(FUNCTION|PROCEDURE)[ \t]+([^ \t]+)\(.*$/\1:\2:'${UMODULE}'\3/' )

	if [ X"$ROUTINES" == 'X' ]; then
	  continue;
	fi

#	echo $ROUTINES;

IFST=$IFS
IFS=';'

	for r in "${ROUTINES}"; do
		echo ${r}
		if [[ X"$r" = 'X' ]]; then
			continue;
		fi
		ROUTINE_DEFS="${ROUTINE_DEFS}${r};"
	done

done

#for rd in "$ROUTINE_DEFS"; do 
#	echo "$rd";
#done
IFS=$IFST

exit;

#ROUTINE_DEFS=$( grep -in ',[[:space:]]*delim VARCHAR(1)'  *.sql | sed -r -e 's/[ ]?CREATE[ ]+([^ ]+)[ ]+([^ ]+)[ ]?\(.*/\1:\2/' )

INST_LINE="IF (LENGTH(\${PARM})>1) THEN SELECT CONCAT(\'delim = \',delim); END IF;"

echo $INST_LINE;

for def in $ROUTINE_DEFS;
do
    echo "$def";
done;


for def in $ROUTINE_DEFS;
do
#    echo "$def";
    rtype=$( echo "$def" | cut -d: -f3 );
    rname=$( echo "$def" | cut -d: -f4 );
	rfile=$( echo "$def" | cut -d: -f1 );

	module=$( head -1 $rfile | sed -e 's/^-- Module:\([^ \t]*\)[ \t]*$/\1./i' )
	
IFST=$IFS;
IFS=';'
    if [[ $rtype == 'PROCEDURE' ]]; then
        locations=$( grep -in "^[^--].*call[[:space:]]*${module}${rname}[[:space:]]*(" *.sql );
    else
        locations=$( grep -in "^[^--].*=[ ].*${module}${rname}[ ]*(" *.sql );
    fi;

	if [[ $locations == '' ]]; then
		echo "No calls for $rname"
		continue;
    else
      echo ""
	fi
	
    for l in $locations;
    do
        echo -n $( echo "$l" | sed -re 's/^([^ \t]+)[ \t]+([^ \t]+)/\1/' )
    done

IFS=$IFST;
done;

echo "";
