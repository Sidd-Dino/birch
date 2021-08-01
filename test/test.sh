#!/usr/bin/env bash

prin() {
    printf "dest: %s\n" "$dest"
    # Strip escape sequences from the first word in the
    # full message so that we can calculate how much padding
    # to add for alignment.
    raw=${1%% *}
    raw=${raw//$'\e[1;3'?m}
    raw=${raw//$'\e[m'}

    # Generate a cursor right sequence based on the length
    # of the above "raw" word. The nick column is a fixed
    # width of '10' so it's simply '10 - word_len'.
    printf -v out '\e[%sC%s' \
        "$((${#raw}>10?0:11-${#raw}))" "$1"

    # Grab the current channel a second time to ensure it
    # didn't change during the printing process.
    [[ -s .c ]] && read -r chan < .c

    # Only display to the terminal if the message destination
    # matches the currently focused buffer.
    #
    # '\e[?25l': Hide the cursor.
    # '\e7':     Save cursor position.
    # '\e[999B': Move the cursor to the bottom.
    # '\e[A':    Move the cursor up a line.
    # '\r':      Move the cursor to column 0.
    # '\e8':     Restore cursor position.
    # '\e[?25h': Unhide the cursor.
    [[ $dest == "$chan" ]] &&
        printf '\e[?25l\e7\e[999B\e[A\r%s\n\r\e8\e[?25h' "$out"

    # Log the message to it's destination temporary file.
    # This is how history, resize and buffer swaps work.
    printf '\r%s\n' "$out" >> "$dest"
}

parse() {
    fields=() word='' from='' whom=''
    [[ -s .c ]] && read -r chan < .c

    # If the first "word" in the raw IRC message contains
    # ':', '@' or '!', split it and grab the sending user
    # nick.
    [[ "${1%% *}" == *[:@!]* ]] && {
        from=${1%% *}
        IFS='!@' read -r whom _ <<< "${from#:}"
        printf "whom: %s\n" "$whom"
    }

    # Read the rest of the message character by character
    # until we reach the first ':'. Once the first colon
    # is hit, break from the loop and assume that everything
    # after it is the message contents.
    #
    # Each word prior to ':' is appended to an array so that
    # we may use each portion.
    while IFS= read -d '' -rn 1 c; do case $c in
        ' ') [[ $word ]] && fields+=("$word") word= ;;
          :) break ;;
          *) word+=$c ;;
    esac; done <<< "${1/"$from"}"

    printf "fields: %s\n" "${fields[*]}"

    # Grab the message contents by stripping everything we've
    # found so far above. Then word wrap each line at 60
    # chars wide. TODO: Pure bash and unrestriced..
    mesg=${1/"${from:+$from }${fields[*]} "} mesg=${mesg#:}
    mesg=$(fold -sw "${BIRCH_COLUMNS:=60}" <<< "$mesg")
    mesg=${mesg//$'\n'/$'\n'            }

    printf "mesg: %s\n" "$mesg"

    # If the field after the typical dest is a channel, use
    # it in place of the regular field. This correctly
    # catches MOTD and join messages.
    case ${fields[2]} in
        \#*|\*) fields[1]=${fields[2]} ;;
             =) fields[1]=${fields[3]} ;;
    esac

    whom=${whom:-$nick}
    dest=${fields[1]:-$chan}

    printf "whom: %s\ndest: %s\n" "$whom" "$dest"

    # If the message itself contains ACTION with surrounding
    # '\001', we're dealing with '/me'. Simply set the type
    # to 'ACTION' so we may specially deal with it below.
    [[ $mesg == *$'\001ACTION'*$'\001'* ]] &&
        fields[0]=ACTION mesg=${mesg/$'\001ACTION' }

    # Color the interesting parts based on their lengths.
    # This saves a lot of space below.
    nc=$'\e[1;3'$(((${#whom}%6)+1))m$whom$'\e[m'
    pu=$'\e[1;3'$(((${#whom}%6)+1))m${whom:0:10}$'\e[m'
    me=$'\e[1;3'$(((${#nick}%6)+1))m$nick$'\e[m'
    mc=$'\e[1;3'$(((${#mesg}%6)+1))m$mesg$'\e[m'
    dc=$'\e[1;3'$(((${#dest}%6)+1))m$dest$'\e[m'

    printf "f0: %s\nf[1]: %s\nf[2]: %s\n"\
            "${fields[0]}" "${fields[1]}" "${fields[2]}"
    printf "dest: %s\n" "$dest"
    # The first element in the fields array points to the
    # type of message we're dealing with.
    case ${fields[0]} in
        PRIVMSG)
            prin "$pu ${mesg//$nick/$me}"

            [[ $dest == *$nick* || $mesg == *$nick* ]] &&
                type -p notify-send >/dev/null &&
                notify-send "birch: New mention" "$whom: $mesg"
        ;;

        ACTION)
            prin "* $nc ${mesg/$'\001'}"
        ;;

        NOTICE)
            prin "NOTE $mesg"
        ;;

        QUIT)
            rm -f "$whom:"

            [[ ${nl[chan]} == *" $whom "* ]] &&
                 prin "<-- $nc has quit ${dc//$dest/$chan}"
        ;;

        PART)
            rm -f "$whom:"

            [[ $dest == "$chan" ]] &&
                prin "<-- $nc has left $dc"
        ;;

        JOIN)
            [[ $whom == "$nick" ]] && chan=$mesg

            : > "$whom:"
            dest=$mesg
            prin "--> $nc has joined $mc"
        ;;

        NICK)
            prin "--@ $nc is now known as $mc"
        ;;

        PING)
            printf 'PONG%s\n' "${1##PING}" >&9
        ;;

        AWAY)
            dest=$nick
            prin "-- Away status: $mesg"
        ;;

        00?|2[56]?|37?|32?)
            printf "dest_bef: %s\n" "$dest"
            dest=\*
            printf "dest_aft: %s\n" "$dest"
        ;;&

        32?)
            mesg="${fields[*]:2} $mesg"
        ;;&

        376)
            printf ""
            #cmd  "${x:-}"
        ;;&

        353)
            [[ -f "$dest" ]] || return

            read -ra ns <<< "$mesg"
            nl[chan]=" $mesg "

            for nf in "${ns[@]/%/:}"; do
                : > "$nf"
            done
        ;;&

        *)
            prin "-- $mesg"
        ;;
    esac
}


C=":calcium.libera.chat 376 sidd-dino :End of /MOTD command."
printf "%s\n" "$C"
parse "${C%%$'\r'*}"

printf "\n=====================================================\n"
A=':calcium.libera.chat 322 sidd-dino ###test 5 :Test Channel. Feel free to test stuff. Use Chanserv to get op/voice'
printf "%s\n" "$A"
parse "${A%%$'\r'*}"
printf "\n"
A=":calcium.libera.chat 321 sidd-dino Channel :Users  Name"
printf "%s\n" "$A"
parse "${A%%$'\r'*}"

printf "\n=====================================================\n"
B=":kyxor!~kyxor@99-26-104-141.lightspeed.miamfl.sbcglobal.net PRIVMSG #kisslinux :there are so many cpp warning that I can\'t even tell what the error is"
printf "%s\n" "$B"
parse "${B%%$'\r'*}"