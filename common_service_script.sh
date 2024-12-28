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
        init|service)
            "$ESCALATION_TOOL" service "$1" start
            ;;
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" start "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" start
            ;;
        runit)
            "$ESCALATION_TOOL" sv start "$1"
            ;;
    esac
}

stopService() {
    case "$INIT_MANAGER" in
        init|service)
            "$ESCALATION_TOOL" service "$1" stop
            ;;
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" stop "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" stop
            ;;
        runit)
            "$ESCALATION_TOOL" sv stop "$1"
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
        runit)
            "$ESCALATION_TOOL" mkdir -p "/run/runit/supervise.$1"
            "$ESCALATION_TOOL" ln -sf "/etc/sv/$1" "/var/service/"
            sleep 2
            ;;
        service)
            update-rc.d "$1" defaults
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
        runit)
            "$ESCALATION_TOOL" rm -f "/var/service/$1"
            ;;
        service)
            update-rc.d -f "$1" remove
            ;;
    esac
}

startAndEnableService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" enable --now "$1"
            ;;
        rc-service)
            enableService "$1"
            startService "$1"
            ;;
        runit)
            enableService "$1"
            startService "$1"
            ;;
        service)
            enableService "$1"
            startService "$1"
            ;;
    esac
}

isServiceActive() {
    case "$INIT_MANAGER" in
        init|service)
            "$ESCALATION_TOOL" service "$1" status | grep -q 'running'
            ;;
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" is-active --quiet "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" status --quiet
            ;;
        runit)
            "$ESCALATION_TOOL" sv status "$1" >/dev/null 2>&1
            ;;
    esac
}

checkInitManager 'systemctl rc-service runit service init'
