#!/bin/sh -e

checkInitManager() {
    for manager in $1; do
        if command_exists "$manager"; then
            INIT_MANAGER="$manager"
            printf "%b\n" "${CYAN}Using ${manager} to interact with init system${RC}"
            break
        fi
    done

    if [ -z "$INIT_MANAGER" ]; then
        printf "%b\n" "${RED}Can't find a supported init system${RC}"
        exit 1
    fi
}

startService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" start "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" start
            ;;
        runit)
            "$ESCALATION_TOOL" sv start "$1"
            ;;
        sysvinit)
            "$ESCALATION_TOOL" service "$1" start
            ;;
    esac
}

stopService() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" stop "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" stop
            ;;
        runit)
            "$ESCALATION_TOOL" sv stop "$1"
            ;;
        sysvinit)
            "$ESCALATION_TOOL" service "$1" stop
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
            ln -s /etc/sv/"$1" /var/service/
            ;;
        sysvinit)
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
            rm /var/service/"$1"
            ;;
        sysvinit)
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
        sysvinit)
            enableService "$1"
            startService "$1"
            ;;
    esac
}

isServiceActive() {
    case "$INIT_MANAGER" in
        systemctl)
            "$ESCALATION_TOOL" "$INIT_MANAGER" is-active --quiet "$1"
            ;;
        rc-service)
            "$ESCALATION_TOOL" "$INIT_MANAGER" "$1" status --quiet
            ;;
        runit)
            "$ESCALATION_TOOL" sv status "$1" | grep -q '^run:'
            ;;
        sysvinit)
            "$ESCALATION_TOOL" service "$1" status | grep -q 'running'
            ;;
    esac
}

checkInitManager 'systemctl rc-service runit sysvinit'
