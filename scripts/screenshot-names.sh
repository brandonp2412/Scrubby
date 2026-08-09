#!/bin/bash
screenshot_name() {
    case "$1" in
        1) echo "HomePage" ;;
        2) echo "SchedulesPage" ;;
        3) echo "RoomsPage" ;;
        4) echo "SettingsPage" ;;
        5) echo "LoginScreen" ;;
        *) echo "$1" ;;
    esac
}
