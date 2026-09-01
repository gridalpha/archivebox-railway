#!/bin/bash
# Runs as the unprivileged archivebox user, exec'd by ArchiveBox's own entrypoint.
set -o errexit
set -o pipefail

PORT="${PORT:-8000}"
DATA_DIR="${DATA_DIR:-/data}"
SCHEDULER_POLL_SECONDS="${SCHEDULER_POLL_SECONDS:-60}"

# `archivebox schedule --foreground` exits non-zero when no jobs are scheduled
# yet, and it cannot see jobs added after it started, so supervise it: re-check
# once a minute and run it whenever the crontab has something in it.
scheduler_loop() {
    while true; do
        if [ -f "$DATA_DIR/index.sqlite3" ] && archivebox schedule --show 2>/dev/null | grep -q .; then
            archivebox schedule --foreground || true
        fi
        sleep "$SCHEDULER_POLL_SECONDS"
    done
}

if [ "${ENABLE_SCHEDULER:-True}" = "True" ]; then
    # Prove at boot that the relocated crontab store is writable by this user,
    # rather than finding out when someone schedules their first job. Writing an
    # empty crontab is only safe while there is none, so it runs once per volume.
    if ! crontab -l >/dev/null 2>&1; then
        if printf '' | crontab - 2>/dev/null; then
            echo "[railway] scheduler crontab store is writable ($DATA_DIR/logs/crontabs)"
        else
            echo "[railway] warning: cannot write the crontab store, 'archivebox schedule' will fail" >&2
        fi
    fi
    scheduler_loop &
fi

# --quick-init creates ./data on first boot and the ADMIN_USERNAME superuser.
exec archivebox server --quick-init "0.0.0.0:${PORT}"
