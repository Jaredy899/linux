#!/bin/sh -e

command_exists() {
    [ -x "/sbin/$1" ] || [ -x "/usr/sbin/$1" ] || [ -x "/bin/$1" ] || [ -x "/usr/bin/$1" ] || command -v "$1" >/dev/null 2>&1
}

checkInitManager() {
    for manager in $1; do
        if command_exists "$manager"; then
            INIT_MANAGER="$manager"
            printf "%b\n" "${CYAN}Using ${manager} to interact with init system${RC}"
            return 0
        fi
    done

    printf "%b\n" "${RED}Can't find a supported init system${RC}"
    exit 1
}

startService() {
    case "$INIT_MANAGER" in
        init|rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" start
            ;;
        systemctl|sv|service)
            if [ "$DISTRO" = "salix" ]; then
                "$ESCALATION_TOOL" "$INIT_MANAGER" start "$1"
            else
                "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" start
            fi
            ;;
    esac
}

stopService() {
    case "$INIT_MANAGER" in
        init|rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" stop
            ;;
        systemctl|sv|service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" stop "$1"
            ;;
    esac
}

enableService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" enable "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" rc-update add "$1"
            ;;
        sv)
            "$ESCALATION_TOOL" mkdir -p "/run/runit/supervise.$1"
            "$ESCALATION_TOOL" ln -sf "/etc/sv/$1" "/var/service/"
            sleep 5
            ;;
        service)
            if command_exists update-rc.d; then
                "$ESCALATION_TOOL" update-rc.d "$1" defaults
            elif [ -f "/etc/rc.d/rc.$1" ]; then
                "$ESCALATION_TOOL" chmod +x "/etc/rc.d/rc.$1"
            elif [ -f "/etc/init.d/$1" ]; then
                "$ESCALATION_TOOL" chmod +x "/etc/init.d/$1"
            else
                printf "%b\n" "${YELLOW}No suitable init script found for $1.${RC}"
                return 1
            fi
            ;;
    esac
}

disableService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" disable "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" rc-update del "$1"
            ;;
        sv)
            "$ESCALATION_TOOL" rm -f "/var/service/$1"
            ;;
        service)
            "$ESCALATION_TOOL" chmod -x /etc/rc.d/rc."$1"
            ;;
    esac
}

startAndEnableService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" enable --now "$1"
            ;;
        rc-service|sv|service)
            enableService "$1"
            startService "$1"
            ;;
    esac
}

isServiceActive() {
    case "$INIT_MANAGER" in
        service)
            if [ "$INIT_MANAGER" = "service" ]; then
                "$ESCALATION_TOOL" "$INIT_MANAGER" list 2>/dev/null \
                    | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' \
                    | grep -q -E "^$1.*\[on\]"
            else
                "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" status | grep -q 'running'
            fi
            ;;
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" is-active --quiet "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" status --quiet
            ;;
        sv)
            "$ESCALATION_TOOL" "$INIT_MANAGER" status "$1" >/dev/null 2>&1
            ;;
    esac
}

checkInitManager 'systemctl rc-service sv service'
