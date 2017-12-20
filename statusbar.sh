#!/bin/bash

#TODO fix size calc for dual monitors
CURRENT_XRES=$(xrandr |grep current|cut -d, -f2 | cut -d" " -f3)

#Some Dzen setup
BASEPATH="~/statusbar/"
ICONPATH=${BASEPATH}"icons/"
FONT="-*-terminus-medium-*-*-*-14-*-*-*-*-*-*-*"
FGCOLOR="#666666"
BGCOLOR="#000000"
WIDTH=$(($CURRENT_XRES/2))
WIDTH=960
HEIGHT=16
XPOS=$(($CURRENT_XRES - $WIDTH))
YPOS=0
if [[ -e ~/.display2 ]]; then
  YPOS=780
fi
DELIM="^fg(#333333) | ^fg()"
NOWPLAYING_TEXT_SIZE=60
NOWPLAYING=""
#Initialize timer counters
UNREAD_TIMER=0
WEATHER_TIMER=0

MPD_HOST='localhost'

#main loop
while true; do

  ### Show battery if not connected to AC
  AC_STATE=$(cat /sys/class/power_supply/AC/online)
  if [ $AC_STATE != "1" ]
  then
    # CHARGE=$(acpi -b | awk -F, '{print $2}')
    TIME_REMAINING=$(acpi -b | head -n 1 |awk '{print $5}')
    #TODO add context aware color
    BATTERY="^fg(#CAE34F)${TIME_REMAINING}$DELIM"
  else
    BATTERY=""
  fi

  ### Date and Time
  DATE=$(date +"%a, %b %d${DELIM}%H:%M^fn("-*-terminus-medium-*-*-*-12-*-*-*-*-*-*-*"):%S^fn()")
  DATE="^ca(1,xclock)$DATE^ca()"

  ## CPU Temp
  CPUTEMP=`acpi -ft | grep "Thermal 0" |sed -e 's/Thermal [01]:.*\,//' -e 's/degrees.*//'`

  # round
  CPUTEMP_INT=`echo "($CPUTEMP+0.5)/1" | bc`

  if [ $CPUTEMP_INT -gt 200 ]
  then
    CPUTEMPCOLOR='#DF0101'
  elif [ $CPUTEMP_INT -gt 165  ]
  then
    CPUTEMPCOLOR='#8A2908'
  else
    CPUTEMPCOLOR=$FGCOLOR
  fi
  CPUTEMP="^fg(${CPUTEMPCOLOR})${CPUTEMP}^bg()"

  ##Weather
  [ $WEATHER_TIMER == -1 ] && {
  WEATHER=`weather-report | grep "Temperature\|Weather\|Sky conditions" | sed -e 's/(.*)//' -e 's/Weather://' -e 's/Temperature://' -e 's/\..*//g' -e 's/Sky conditions://' -e 's/\ \ //g' | tr '\n' " "`

  #Check every 20 mins
  WEATHER_TIMER=1000
}

###Volume
#VOL=$(amixer get Master |grep -o [0-9]*% | cut -d% -f1 > ~/testpipe )
#	echo "<vol> $(amixer get Master |grep -o [0-9]*% | cut -d% -f1  )" > /home/joneill/testpipe
#
#        echo "$t" | grep -q "^<vol>"
#	if [ $? -eq 0 ]; then
#	  VOL=${t:5}
#	fi
#	VOL="^i(${ICONPATH}vol-mute.xbm) "${VOL}

##Unread Email - reads counts output by external script get_unseen_counts.pl
#	[ $UNREAD_TIMER == -1 ] && {
#	UNREAD_ARRAY=$(cat ${BASEPATH}unseenCount.txt)
#	UNREAD=
#	ICONCOLOR=$FGCOLOR
#	for i in ${UNREAD_ARRAY[@]}
#		do
#			if [ "$i" -gt 0 ]
#			then
#				UNREADCOLOR='#00AC58'
#				ICONCOLOR=$UNREADCOLOR
#			else
#				i='-'
#				UNREADCOLOR='#333333'
##			fi
##			UNREAD="${UNREAD} ^fg(${UNREADCOLOR})${i}^fg()"
#		done
#	UNREAD="^fg(${ICONCOLOR})^i(${ICONPATH}envelope.xbm)^fg()  "${UNREAD}
#	##Check manually on click
#	UNREAD="${BASEPATH}get_unseen_mail_counts.pl )${UNREAD}"
#	UNREAD_TIMER=3
#	}

if [ "$(pidof mpd)" ] || [ "$(pidof mopidy)"] ; then

  NOWPLAYING=$(mpc  -h $MPD_HOST|sed -n 2p)
  if [ $(echo "$NOWPLAYING" | grep "paused") ]; then
    NOWPLAYING="--PAUSED--"
  else
    NOWPLAYING=$(mpc -h $MPD_HOST -f "%file%~%name%~%artist%~%title%"| head -n 1)
    IFS='~'
    set $NOWPLAYING
    if [ $(echo $NOWPLAYING|grep "^http") ]
    then
      if [ $4 ]
      then
        NOWPLAYING="$4"
      else
        NOWPLAYING="$2"
      fi
    else
      NOWPLAYING="$3 - $4"
    fi

    if [[ ${#NOWPLAYING} -gt $NOWPLAYING_TEXT_SIZE ]]; then
      # Text is too long, need to scroll
      # from https://github.com/livibetter/dotfiles/blob/master/dzen/status.sh
      #http://blog.yjl.im/2010/12/my-dzen-status-bar.html
      if [[ $mpd_text_dir ]]; then
        # scroll right
        if ((++mpd_text_pos >= ${#NOWPLAYING} + 5 - NOWPLAYING_TEXT_SIZE)); then
          mpd_text_pos=$((${#NOWPLAYING} - NOWPLAYING_TEXT_SIZE))
          mpd_text_dir=
        fi
      else
        # scroll left, will be first direction since $mpd_text_dir is unset by default
        if ((--mpd_text_pos <= -5)); then
          mpd_text_pos=0
          mpd_text_dir=1
        fi
      fi
      pos=$mpd_text_pos
      [[ $pos -lt 0 ]] && pos=0
      ((pos > ${#NOWPLAYING} - NOWPLAYING_TEXT_SIZE)) && pos=$((${#NOWPLAYING} - NOWPLAYING_TEXT_SIZE))
    fi
    NOWPLAYING="^fn("-*-terminus-medium-*-*-*-12-*-*-*-*-*-*-*")(mpd) ${NOWPLAYING:$pos:$NOWPLAYING_TEXT_SIZE}^fn()"
  fi
else
  NOWPLAYING=""
fi

if [ "$(pidof pianobar)" ]; then
  NOWPLAYING=$(cat ~/.config/pianobar/statusbar)
fi

### Put the string togather
#echo ${NOWPLAYING}${DELIM}${CPUTEMP}${DELIM}${UNREAD}${DELIM}${WEATHER}${DELIM}${DATE}${LOGOUT}
echo ${NOWPLAYING}${DELIM}${BATTERY}${CPUTEMP}${DELIM}${WEATHER}${DELIM}${DATE}${LOGOUT}

#Increment timers
((WEATHER_TIMER=WEATHER_TIMER-1))
#	((UNREAD_TIMER=UNREAD_TIMER-1))
sleep 1

done | dzen2 -fn $FONT -fg $FGCOLOR -bg $BGCOLOR -ta r -x $XPOS -y $YPOS -h $HEIGHT -tw $WIDTH -u

