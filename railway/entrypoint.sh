#!/bin/bash
# Runs as root, before ArchiveBox's own entrypoint drops to the archivebox user.
# Only job: put the scheduler's crontab on the volume, then hand over unchanged.
set -o errexit
set -o pipefail

DATA_DIR="${DATA_DIR:-/data}"
CRONTAB_DIR="$DATA_DIR/crontabs"
SPOOL_DIR=/var/spool/cron/crontabs

relocate_crontabs() {
    mkdir -p "$CRONTAB_DIR"
    # 1730 root:crontab is what Debian ships; ArchiveBox's entrypoint re-owns
    # everything under $DATA_DIR to the archivebox user a moment from now, which
    # leaves the directory writable by the user that runs `crontab`.
    chmod 1730 "$CRONTAB_DIR"
    if [ ! -L "$SPOOL_DIR" ]; then
        rm -rf "$SPOOL_DIR"
        ln -s "$CRONTAB_DIR" "$SPOOL_DIR"
    fi
    echo "[railway] scheduler crontab dir: $SPOOL_DIR -> $CRONTAB_DIR"
}

# The web server matters more than the scheduler: never fail the boot over this.
relocate_crontabs || echo "[railway] warning: could not relocate the crontab dir, schedules will not survive a redeploy" >&2

exec /app/bin/docker_entrypoint.sh /app/railway/serve.sh
