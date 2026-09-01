#!/bin/bash
# Runs as root, before ArchiveBox's own entrypoint drops to the archivebox user.
# Only job: put the scheduler's crontab on the volume, then hand over unchanged.
set -o errexit
set -o pipefail

DATA_DIR="${DATA_DIR:-/data}"
# ArchiveBox's `init` refuses to start in a data dir containing anything it does
# not recognise (ALLOWED_IN_OUTPUT_DIR), so the crontab cannot live at the top of
# the volume next to Railway's lost+found. `logs/` is on that allow-list.
CRONTAB_DIR="$DATA_DIR/logs/crontabs"
SPOOL_DIR=/var/spool/cron/crontabs

relocate_crontabs() {
    ab_uid="$(id -u archivebox)"
    ab_gid="$(id -g archivebox)"

    mkdir -p "$DATA_DIR/logs"
    # Earlier images kept it one level up; carry those schedules over.
    if [ -d "$DATA_DIR/crontabs" ] && [ ! -e "$CRONTAB_DIR" ]; then
        mv "$DATA_DIR/crontabs" "$CRONTAB_DIR"
    fi
    rm -rf "$DATA_DIR/crontabs"

    mkdir -p "$CRONTAB_DIR"
    # 1730 is what Debian ships for the spool dir; the owner is the user that
    # runs `archivebox schedule`, so it can write its own crontab there.
    chown "$ab_uid:$ab_gid" "$CRONTAB_DIR"
    chmod 1730 "$CRONTAB_DIR"

    if [ "$(readlink "$SPOOL_DIR" || true)" != "$CRONTAB_DIR" ]; then
        rm -rf "$SPOOL_DIR"
        ln -s "$CRONTAB_DIR" "$SPOOL_DIR"
    fi
    echo "[railway] scheduler crontab dir: $SPOOL_DIR -> $CRONTAB_DIR"
}

# The web server matters more than the scheduler: never fail the boot over this.
relocate_crontabs || echo "[railway] warning: could not relocate the crontab dir, schedules will not survive a redeploy" >&2

exec /app/bin/docker_entrypoint.sh /app/railway/serve.sh
