# archivebox-railway

Deployment image for running [ArchiveBox](https://github.com/ArchiveBox/ArchiveBox)
on [Railway](https://railway.com).

It is one layer on top of the published `archivebox/archivebox:latest` image:

- **The scheduler runs beside the web server.** Upstream's `docker-compose.yml`
  runs `archivebox schedule --foreground` as a second container that shares the
  `./data` directory. Railway volumes are strictly one-per-service, so that role
  runs as a supervised child process of the web server instead.
- **The scheduler's crontab lives on the volume.** `/var/spool/cron/crontabs` is
  container-local, so schedules added with `archivebox schedule --every=day …`
  would be lost on the next deploy. It is symlinked to `/data/crontabs`.

Nothing else about the image is changed: ArchiveBox's own entrypoint still fixes
up volume ownership and drops to the unprivileged `archivebox` user.

## Configuration

Everything is configured with ArchiveBox's own environment variables — see
<https://github.com/ArchiveBox/ArchiveBox/wiki/Configuration>. Two extras are
added by this image:

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8000` | port the web server binds |
| `ENABLE_SCHEDULER` | `True` | set to anything else to run the web server alone |
| `SCHEDULER_POLL_SECONDS` | `60` | how often the supervisor looks for new schedules |

## Adding a recurring archive job

```bash
railway ssh -s archivebox
archivebox schedule --every=day --depth=1 'https://example.com/feed.xml'
```

The supervisor picks it up within a minute, and the schedule survives redeploys.
