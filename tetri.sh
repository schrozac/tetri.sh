#!/bin/bash

# ======
#  INIT
# ======
ROWS=20
COLS=10
TOTAL=$((ROWS * COLS))
CELLS=()
CHANGED=0

for ((i=0;i<200;i+=1)); do 
	CELLS[i]=0
done

GRAVITY=2
COUNTER=1
CURSOR_R=0
GHOST_R=0
CURSOR_C=4

REPEAT_DELAY=200
REPEAT_RATE=15
#LOCK_DELAY=0.1s

DEFAULT=20

PIECE=-1
HOLD_PIECE=-1
NEXT_PIECES=()

HOLD_R=2
HOLD_C=-4

NEXT_R=1
NEXT_C=14

TEXT_R=8
TEXT_C=-5

ROW_OFFSET=2
COL_OFFSET=8

ROTATION=0
LAST_ROTATION=0

LOCK_COUNTER=-1
LOCK_TIME=8

STYLE='[]'
if [ $# -gt 0 ]; then
  STYLE=$1
fi

VALID=1

BAG=()
BAG_SHUFFLES=20

# ========
#  PIECES 
# ========

				  #Color      #Square offsets
PIECE_DESCRIPTORS=(	103	0 	0 	1 	0	0  -1	1  -1 	#O
					43	0	0  -1	0	1	0	1  -1	#L
				   	44	0	0  -1  -1  -1 	0 	1 	0 	#J
				   	42	0	0  -1 	0 	0  -1 	1  -1   #S
				   	41	0 	0  -1  -1	0  -1	1 	0	#Z
				   	45	0	0  -1	0  	0  -1 	1	0	#T
				   	46	0	0  -1 	0  -2	0	1	0	#I
				   ) 
DESCRIPTOR_SIZE=9

TEXT=( "      " "SINGLE" "DOUBLE" "TRIPLE" "TETRIS" )

SPINS=( -1 0 -1 1 0 -2 -1 -2 ) 	#L, J, S, Z, T
SPIN_SCALES=( 1 1 -1 -1 -1 1 1 -1 )

NUM_PIECES=$((${#PIECE_DESCRIPTORS[@]} / $DESCRIPTOR_SIZE))
COLOR=${PIECE_DESCRIPTORS[0]}
ALT_COLOR=231
xset_exists=1

# ===========
#  FUNCTIONS
# ===========

checkXSet() {
    command -v xset
}

resetKeys() {
    if [[ $xset_exists -eq 0 ]]; then
        xset r 45
        xset r 46
        xset r 25
        xset r 65
        xset r rate
    fi
}

setKeys() {
    if [[ $xset_exists -eq 0 ]]; then
        xset r rate $REPEAT_DELAY $REPEAT_RATE
        xset -r 45
        xset -r 46
        xset -r 25
        xset -r 65
    fi
}

lowestPosition() {
	temp_r=$CURSOR_R
	temp_lock=$LOCK_COUNTER

	until [[ $CHANGED -gt 0 ]]; do
		moveDown
	done

	GHOST_R=$CURSOR_R
	CURSOR_R=$temp_r
	LOCK_COUNTER=$temp_lock
}

index() {
	INDEX=$((($1 * 10) + $2))
}

# Draw $3 at row $1, col $2
plot_char(){     
	echo -e "\033[${1};${2}H"$3
}

plot() {
	PLOT_R=$(($1 + $ROW_OFFSET))
	PLOT_C=$((2 * ($2 + $COL_OFFSET)))
	if [[ $PLOT_C -ge 0 && $PLOT_R -ge 2 ]]; then
		if [[ $3 -gt 0 ]]; then
			echo -en "\033[0m\033[1;38;5;${ALT_COLOR}m"
			echo -e "\033[$3m\033[${PLOT_R};${PLOT_C}H$4"
		else
			echo -e "\033[0m\033[${PLOT_R};${PLOT_C}H  "
		fi
	fi
}

drawText() {
	STR="${TEXT[@]:$1:1}"
	getAltColor 0
	plot $TEXT_R $TEXT_C 1 "$STR"
}


getOffsets() {
	y=${PIECE_DESCRIPTORS[$((($1 * $DESCRIPTOR_SIZE) + ($2 * 2) + 1))]}
	x=${PIECE_DESCRIPTORS[$((($1 * $DESCRIPTOR_SIZE) + ($2 * 2) + 2))]}

	# Build array of rotations
	results=($x $y $y $((x*-1)) $((x*-1)) $((y*-1)) $((y*-1)) $x)

	dx=${results[$(($3 * 2))]}
	dy=${results[$(($3 * 2 + 1))]}
}

getSmaller() {
	DIFF=$(($1 - $2))

	if [[ $1 -lt $2 ]]; then
		SMALLER=$1
	else
		SMALLER=$2
	fi
}

getSpin() {
	getSmaller $2 $ROTATION

	SCALE_X=${SPIN_SCALES[$((SMALLER * 2))]}
	SCALE_Y=${SPIN_SCALES[$((SMALLER * 1))]}

	if [[ $SMALLER -lt $ROTATION ]]; then
		# smaller is $2, so we're going high to low
		SCALE_Y=$((SCALE_Y * -1))
		SCALE_X=$((SCALE_X * -1))
	fi

	# I don't think all this is necessary but it works
	if [[ ${DIFF#-} -gt 1 ]]; then
		SCALE_X=$((SCALE_X * -1))
	fi

	if [[ $SMALLER -gt 0 ]]; then
		SCALE_Y=$((SCALE_Y * -1))
	fi

	SPIN_Y=$((${SPINS[$(($1 * 2))]} * $SCALE_X))
	SPIN_X=$((${SPINS[$(($1 * 2 + 1))]} * $SCALE_Y * -1))
}

moveLeft() {
	CURSOR_C=$(($CURSOR_C - 1))
	BLOCKED=0
	for ((j=0;j<4;j+=1)); do
		getOffsets $PIECE $j $ROTATION
		index $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy))

		if [[ $(($CURSOR_C + $dy)) -lt 0 ||  $INDEX -lt 0 || $INDEX -gt 199 || ${CELLS[$(($INDEX))]} -gt 0 ]]; then
			BLOCKED=1
			break
		fi
	done

	if [[ $BLOCKED -gt 0 ]]; then
		CURSOR_C=$(($CURSOR_C + 1))
	fi
}

moveRight() {
	CURSOR_C=$(($CURSOR_C + 1))
	BLOCKED=0
	for ((j=0;j<4;j+=1)); do
		getOffsets $PIECE $j $ROTATION
		index $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy))

		if [[ $(($CURSOR_C + $dy)) -gt 9 ||  $INDEX -lt 0 || $INDEX -gt 199 || ${CELLS[$(($INDEX))]} -gt 0 ]]; then
			BLOCKED=1
			break
		fi
	done

	if [[ $BLOCKED -gt 0 ]]; then
		CURSOR_C=$(($CURSOR_C - 1))
	fi
}

checkRotation() {
	VALID=0
	for ((j=0;j<4;j+=1)); do
		getOffsets $PIECE $j $1
		index $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy))
		if [[ $(($CURSOR_R + $dx)) -gt 19 || $(($CURSOR_C + $dy)) -lt 0 || $(($CURSOR_C + $dy)) -gt 9 ||  $INDEX -lt 0 || $INDEX -gt 199 || ${CELLS[$(($INDEX))]} -gt 0 ]]; then
			VALID=1
			break
		fi
	done

	if [[ $VALID -gt 0 ]]; then
		# Test each spin
		for ((k=0;k<4;k+=1)); do
			VALID=0
			getSpin $k $1

			# Test each square
			for ((j=0;j<4;j+=1)); do
				getOffsets $PIECE $j $1

				TEMP_R=$(($CURSOR_R + $dx + $SPIN_X))
				TEMP_C=$(($CURSOR_C + $dy + $SPIN_Y))
				index $TEMP_R $TEMP_C
				if [[ $TEMP_R -gt 19 || $TEMP_C -lt 0 || $TEMP_C -gt 9 ||  $INDEX -lt 0 || $INDEX -gt 199 || ${CELLS[$(($INDEX))]} -gt 0 ]]; then
					VALID=1
					break
				fi
			done

			if [[ $VALID -eq 0 ]]; then
				CURSOR_R=$(($CURSOR_R + $SPIN_X))
				CURSOR_C=$(($CURSOR_C + $SPIN_Y))
				break
			fi
		done
	fi
}

spinRight() {
	temp=$((($ROTATION + 1) % 4))
	checkRotation $temp
	if [[ $VALID -eq 0 ]]; then
		ROTATION=$temp
		LOCK_COUNTER=0
	fi
}

spinLeft() {
	temp=$((($ROTATION + 3) % 4))
	checkRotation $temp
	if [[ $VALID -eq 0 ]]; then
		ROTATION=$temp
		LOCK_COUNTER=0
	fi
}

getAltColor() {
	case $1 in
		103) #yellow
			ALT_COLOR=178;;
		43) #orange
			ALT_COLOR=172;;
		44) #blue
			ALT_COLOR=33;;
		42) #green
			ALT_COLOR=48;;
		41) #red
			ALT_COLOR=161;;
		45) #purple
			ALT_COLOR=135;;
		46) #light blue
			ALT_COLOR=87;;
		*)  #ghost
			ALT_COLOR=231;;
	esac
}

getColor() {
	COLOR=${PIECE_DESCRIPTORS[@]:$(( $1*$DESCRIPTOR_SIZE )):1}
	getAltColor $COLOR
}

resetPiece() {
	CURSOR_R=0
	CURSOR_C=4
	ROTATION=0
	LOCK_COUNTER=-1
}

shuffleBag(){
	for ((j=0;j<300;j+=1)); do
		swapPair
	done
}

swapPair(){
	index1=$((RANDOM%7))
	index2=$((RANDOM%7))

	if [ "$index1" = "$index2" ]; then
		index2=$(( ($index1+1)%7 ))
	fi

	swapped=${BAG[@]:$index1:1}
	BAG[$index1]=${BAG[@]:$index2:1}
	BAG[$index2]=$swapped;
}

generateNewBag() {
	BAG=(0 1 2 3 4 5 6)
	shuffleBag

	for i in ${BAG[@]}; do
		addNextPiece $i
	done
}

getNewPiece() {
	# Get new piece
	PIECE=${NEXT_PIECES[@]:0:1}
	getColor $PIECE

	# Shift next pieces
	for ((i=1;i<${#NEXT_PIECES[@]};i++)); do
		NEXT_PIECES[$(($i-1))]=${NEXT_PIECES[@]:$i:1}
	done
	unset NEXT_PIECES[$((${#NEXT_PIECES[@]} - 1))]

	# Generate next bag
	if [[ ${#NEXT_PIECES[@]} -lt $(($NUM_PIECES-1)) ]]; then
		generateNewBag
	fi
}

addNextPiece() {
	NEXT_PIECES[${#NEXT_PIECES[@]}]=$1
}

movePromptToBottom() {
	T_ROWS=$(tput lines)
	P_ROWS=$((T_ROWS - 1))
	echo -e "\033[$((T_ROWS - 1));1H"
}

solidify() {
	GAMEOVER=0

	# Try to add piece to game state
	for ((j=0;j<4;j+=1)); do
		getOffsets $PIECE $j $ROTATION
		index $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy))

		if [[ $INDEX -lt 0 || $INDEX -gt 199 ]]; then
			if [[ $GAMEOVER -eq 0 ]]; then
				GAMEOVER=1
				NEXT_PIECES=()
				HOLD_PIECE=-1
			fi
		else
			CELLS[$((INDEX))]=$COLOR
		fi
	done

	if [[ $GAMEOVER -eq 0 ]]; then
		resetPiece
		getNewPiece

		clearLines
		drawText $NUM_CLEARED

		lowestPosition
	fi
}


moveDown() {
	CURSOR_R=$(($CURSOR_R + 1))
	for ((j=0;j<4;j+=1)); do
		getOffsets $PIECE $j $ROTATION
		index $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy))
		if [[ $(($CURSOR_R + $dx)) -gt 19 || $INDEX -lt 0 || $INDEX -gt 199 || ${CELLS[$(($INDEX))]} -gt 0 ]]; then
			CHANGED=1
			break
		fi
	done

	if [[ $CHANGED -gt 0 ]]; then
		CURSOR_R=$(($CURSOR_R - 1))
		if [[ $LOCK_COUNTER -lt 0 ]]; then
			LOCK_COUNTER=0
		fi
	else
		LOCK_COUNTER=-1
	fi 
}

clearLine() {
	start=$(($1 * 10 + 9))
	for ((i=$start;i>=10;i-=1)); do
		CELLS[$i]=${CELLS[$(($i - 10))]};
	done
	for ((i=0;i<10;i+=1)); do
		CELLS[$i]=0;
	done
}

clearLines() {
	NUM_CLEARED=0
	for ((r=0;r<20;r+=1)); do
		FULL=0
		for ((c=0;c<10;c+=1)); do
			index $r $c
			if [[ ${CELLS[$INDEX]} -eq 0 ]]; then
				FULL=1
			fi
		done

		if [[ $FULL -eq 0 ]]; then
			plot $DEFAULT 1 0 $STYLE

			clearLine $r
			#r=$(($r+1))
			NUM_CLEARED=$((NUM_CLEARED + 1))
		fi
	done

	if [[ $NUM_CLEARED -gt 0 ]]; then
		drawCells
	fi
}

draw_box() {
	HORZ="-"
	VERT="|"
	CORNER_CHAR="+"

	BOX_HEIGHT=`expr $3 - 1`   #  -1 correction needed because angle char "+"
	BOX_WIDTH=`expr $4 - 1`    #+ is a part of both box height and width.
	T_ROWS=`tput lines`        #  Define current terminal dimension 
	T_COLS=200                                # End checking arguments.

	echo -ne "\033[3${5}m"               # Set box frame color, if defined.

	count=1                                         #  Draw vertical lines using
	for (( r=$1; count<=$BOX_HEIGHT; r++)); do      #+ plot_char function.
	  plot_char $r $2 $VERT
	  let count=count+1
	done 

	count=1
	c=`expr $2 + $BOX_WIDTH`
	for (( r=$1; count<=$BOX_HEIGHT; r++)); do
	  plot_char $r $c $VERT
	  let count=count+1
	done 

	count=1                                        #  Draw horizontal lines using
	for (( c=$2; count<=$BOX_WIDTH; c++)); do      #+ plot_char function.
	  plot_char $1 $c $HORZ
	  let count=count+1
	done 

	count=1
	r=`expr $1 + $BOX_HEIGHT`
	for (( c=$2; count<=$BOX_WIDTH; c++)); do
	  plot_char $r $c $HORZ
	  let count=count+1
	done 

	plot_char $1 $2 $CORNER_CHAR                   # Draw box angles.
	plot_char $1 `expr $2 + $BOX_WIDTH` $CORNER_CHAR
	plot_char `expr $1 + $BOX_HEIGHT` $2 $CORNER_CHAR
	plot_char `expr $1 + $BOX_HEIGHT` `expr $2 + $BOX_WIDTH` $CORNER_CHAR
	echo -ne "\033[0m"             #  Restore old colors.

	movePromptToBottom
}

drawCells() {
	# Draw saved state
	for ((i=0;i<200;i+=1)); do
		r=$((($i / 10)))
		c=$((($i % 10)))
		value=${CELLS[@]:$i:1}
		if [[ $value -gt 0 ]]; then
			getAltColor $value
			plot $r $c $value $STYLE
		else
			plot $r $c 0 $STYLE
		fi
	done 

	# Clear hold area
	for ((r=0;r<4;r+=1)); do
		for ((c=-6;c<-1;c+=1)); do
			plot $r $c 0 $STYLE
		done
	done

	# Clear hold area
	for ((r=0;r<14;r+=1)); do
		for ((c=11;c<16;c+=1)); do
			plot $r $c 0 $STYLE
		done
	done

	# Draw hold piece
	if [[ $HOLD_PIECE -ge 0 ]]; then
		getColor $HOLD_PIECE
		for ((j=0;j<4;j+=1)); do
			getOffsets $HOLD_PIECE $j 0
			plot $(($HOLD_R + $dx)) $(($HOLD_C + $dy)) $COLOR $STYLE
		done
	fi

	# Draw next pieces
	NEXT_PIECE_OFFSET=3
	for ((i=0; i < 5 && i < ${#NEXT_PIECES[@]};i+=1)); do
		getColor ${NEXT_PIECES[@]:$i:1}
		for ((j=0;j<4;j+=1)); do
			getOffsets ${NEXT_PIECES[$i]} $j 0
			plot $(($NEXT_R + $dx + $(($i * $NEXT_PIECE_OFFSET)))) $(($NEXT_C + $dy)) $COLOR $STYLE
		done
	done

	getColor $PIECE
}

hold() {
	temp=$HOLD_PIECE
	HOLD_PIECE=$PIECE
	resetPiece
	if [[ $temp -ge 0 ]]; then
		PIECE=$temp
	else
		getNewPiece
	fi

	getColor $PIECE
	lowestPosition
}

# ======
#  MAIN
# ======

# Hide user input
ORIG_STTY=$(stty -g)
stty -echo

clear

checkXSet
xset_exists=$?

# Draw playfield
draw_box 1 15 22 22 100

# Draw hold box
draw_box 1 3 6 12 100

# Draw next box
draw_box 1 37 16 12 100

# Draw text
plot_char 0 7 HOLD
plot_char 0 41 NEXT
plot $DEFAULT 1 0 $STYLE

# Generate initial bag and piece
generateNewBag
getNewPiece
drawCells

# Decrease key delay, disable auto repeat for rotation/hold
setKeys

# Main loop
while true; do
	if [[ $GAMEOVER -gt 0 ]]; then
		for ((j=0;j<21;j+=1)); do
			clearLine 20
			drawCells
			getAltColor 0
			plot 6 3 1 "GAME OVER"
			movePromptToBottom
			sleep 1
		done	
		plot $DEFAULT 1 0 $STYLE
		break
	else
		CHANGED=0
		COUNTER=$(($COUNTER + 1))

		if [[ $LOCK_COUNTER -ge 0 ]]; then
			LOCK_COUNTER=$(($LOCK_COUNTER + 1))
			if [[ $LOCK_COUNTER -gt $LOCK_TIME ]]; then
				moveDown #just in case the block slid off
				if [[ $CHANGED -gt 0 ]]; then
					solidify
					continue
				fi
			fi 
		fi

		CUR_R=$CURSOR_R
		CUR_C=$CURSOR_C
		GHO_R=$GHOST_R
		LAST_ROTATION=$ROTATION

		if [[ $COUNTER -gt $GRAVITY ]]; then
			COUNTER=$(($COUNTER - $GRAVITY))
			moveDown
		fi

		plot $DEFAULT 1 0 $STYLE

		REPLY=''
		read -s -n 1 -t 1

		# Read keys
		case $REPLY in
		    [Ww]) 
				lowestPosition
				CURSOR_R=$GHOST_R
				for ((j=0;j<4;j+=1)); do
					getOffsets $PIECE $j $ROTATION
					plot $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy)) $COLOR $STYLE
				done
				solidify

				drawCells
				continue;;
		    [Ss]) moveDown;;
			[Aa]) moveLeft;;
		    [Dd]) moveRight;;
			[Kk]) spinLeft;;
			[Ll]) spinRight;;
			[' '])
				hold 
				drawCells
				continue;;
		esac

		# Undraw current piece if necessary
		if [[ ! $CHANGED -gt 0 ]] || [[ $LOCK_COUNTER -ge 0 && $LOCK_COUNTER -le $LOCK_TIME ]]; then
			for ((j=0;j<4;j+=1)); do
				getOffsets $PIECE $j $LAST_ROTATION
				plot $(($CUR_R + $dx)) $(($CUR_C + $dy)) 0 $STYLE
			done

			# Undraw ghost piece
			for ((j=0;j<4;j+=1)); do
				getOffsets $PIECE $j $LAST_ROTATION
				plot $(($GHO_R + $dx)) $(($CUR_C + $dy)) 0 $STYLE
			done
		fi

		# Draw ghost piece if necessary
		lowestPosition
		if [[ ! $GHOST_R -eq $CURSOR_R ]]; then
			for ((j=0;j<4;j+=1)); do
				getColor $PIECE
				getAltColor 0
				getOffsets $PIECE $j $ROTATION
				plot $(($GHOST_R + $dx)) $(($CURSOR_C + $dy)) 1 $STYLE
			done
		fi

		# Draw current piece
		for ((j=0;j<4;j+=1)); do
			getColor $PIECE
			getOffsets $PIECE $j $ROTATION
			plot $(($CURSOR_R + $dx)) $(($CURSOR_C + $dy)) $COLOR $STYLE
		done
	fi
done

# Reset key rate
resetKeys

# Reset color
echo -e "\033(B\033[m"

# Un-hide user input
stty ${ORIG_STTY}
