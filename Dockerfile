# ArchiveBox on Railway
#
# One layer on top of the published image. It adds two things the published
# image cannot do here:
#
#   1. Upstream's docker-compose runs the archiving scheduler as a second
#      container sharing ./data. Railway volumes are strictly 1:1, so the
#      scheduler runs inside this container instead, supervised by serve.sh.
#   2. That scheduler's crontab lives in /var/spool/cron/crontabs, which is
#      container-local and would be lost on every redeploy. entrypoint.sh
#      relocates it onto the volume before privileges are dropped.
FROM archivebox/archivebox:latest

USER root

COPY railway/ /app/railway/

RUN chmod 0755 /app/railway/entrypoint.sh /app/railway/serve.sh \
    && bash -n /app/railway/entrypoint.sh \
    && bash -n /app/railway/serve.sh

WORKDIR /data

ENTRYPOINT ["dumb-init", "--", "/app/railway/entrypoint.sh"]
