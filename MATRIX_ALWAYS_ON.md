# Matrix Server - Always Running Configuration

The Matrix server is configured to always be running and automatically restart.

## Current Configuration

### Docker Restart Policy

All Matrix services are configured with `restart: always` in `docker-compose.yml`:
- **Synapse** (Matrix homeserver)
- **PostgreSQL** (database)
- **Redis** (cache)
- **Element Web** (web client)

This means:
- Services automatically restart if they crash
- Services start automatically when Docker daemon starts
- Services persist across system reboots (if Docker starts on boot)

## Ensuring Matrix Starts on System Boot

### Quick Check

Run this script to verify Matrix is running:
```bash
./scripts/ensure-matrix-running.sh
```

This will:
- Check if Docker is running
- Check if all Matrix containers are running
- Start any stopped containers
- Verify connectivity

### Automatic Startup Installation

To ensure Matrix starts automatically when your computer boots:

```bash
./scripts/install-autostart.sh
```

This installs:
- **macOS:** LaunchAgent that starts Matrix on login
- **Linux:** systemd service that starts Matrix on boot

## Manual Control

### Start Matrix
```bash
docker-compose up -d
```

### Stop Matrix
```bash
docker-compose stop
```

### Restart Matrix
```bash
docker-compose restart
```

### View Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f synapse
docker-compose logs -f postgres
```

## Monitoring

### Health Check
```bash
# Quick health check
curl http://localhost:8008/health

# Full status check
./scripts/ensure-matrix-running.sh
```

### Container Status
```bash
# List running containers
docker ps | grep matrix

# Detailed status
docker-compose ps
```

## Troubleshooting

### Matrix Not Running After Reboot

1. **Check Docker is running:**
   ```bash
   docker info
   ```

2. **Start Docker Desktop (Mac) or Docker daemon (Linux):**
   - Mac: Open Docker Desktop application
   - Linux: `sudo systemctl start docker`

3. **Start Matrix:**
   ```bash
   docker-compose up -d
   ```

4. **Install autostart (if not done):**
   ```bash
   ./scripts/install-autostart.sh
   ```

### Container Keeps Restarting

Check logs for errors:
```bash
docker-compose logs synapse
```

Common issues:
- Database connection problems
- Configuration errors in `homeserver.yaml`
- Port conflicts (8008, 8448, 8080)

### High Resource Usage

Matrix can use significant resources. To limit:

1. Edit `docker-compose.yml` and add resource limits:
```yaml
synapse:
  # ... existing config ...
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        memory: 512M
```

2. Restart services:
```bash
docker-compose up -d
```

## Maintenance

### Update Matrix
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

### Backup
```bash
# Backup database and data
docker-compose exec postgres pg_dump -U synapse synapse > backup.sql
tar -czf matrix-data-backup.tar.gz matrix-data/
```

### Clean Up
```bash
# Remove old logs
docker-compose exec synapse find /data -name "*.log.*" -mtime +30 -delete

# Prune old Docker images
docker image prune -a
```

## Performance Optimization

### For Always-On Operation

1. **Enable Redis caching** (already configured)
2. **Configure log rotation** in `homeserver.yaml`
3. **Set up monitoring** (Prometheus/Grafana)
4. **Regular database maintenance:**
   ```bash
   docker-compose exec postgres vacuumdb -U synapse -d synapse -z
   ```

## Security Considerations

Since Matrix is always running:

1. **Keep it updated:**
   ```bash
   docker-compose pull && docker-compose up -d
   ```

2. **Monitor logs for suspicious activity:**
   ```bash
   docker-compose logs synapse | grep -i "error\|warn\|fail"
   ```

3. **Use strong passwords** for all accounts

4. **Enable rate limiting** in `homeserver.yaml`

5. **Regular backups** (automated recommended)

## Integration with System

### macOS LaunchAgent

Location: `~/Library/LaunchAgents/com.inquiryinstitute.matrix.plist`

Commands:
```bash
# Start
launchctl start com.inquiryinstitute.matrix

# Stop
launchctl stop com.inquiryinstitute.matrix

# Unload (disable autostart)
launchctl unload ~/Library/LaunchAgents/com.inquiryinstitute.matrix.plist

# Reload (enable autostart)
launchctl load ~/Library/LaunchAgents/com.inquiryinstitute.matrix.plist
```

### Linux systemd Service

Location: `/etc/systemd/system/matrix-homeserver.service`

Commands:
```bash
# Start
sudo systemctl start matrix-homeserver

# Stop
sudo systemctl stop matrix-homeserver

# Status
sudo systemctl status matrix-homeserver

# Enable autostart
sudo systemctl enable matrix-homeserver

# Disable autostart
sudo systemctl disable matrix-homeserver

# View logs
sudo journalctl -u matrix-homeserver -f
```

## Quick Reference

| Task | Command |
|------|---------|
| Check if running | `./scripts/ensure-matrix-running.sh` |
| Start Matrix | `docker-compose up -d` |
| Stop Matrix | `docker-compose stop` |
| Restart Matrix | `docker-compose restart` |
| View logs | `docker-compose logs -f synapse` |
| Health check | `curl http://localhost:8008/health` |
| Install autostart | `./scripts/install-autostart.sh` |
| Update Matrix | `docker-compose pull && docker-compose up -d` |

## Support

If Matrix is not staying running:

1. Check Docker daemon status
2. Review container logs: `docker-compose logs`
3. Verify disk space: `df -h`
4. Check system resources: `docker stats`
5. Review autostart configuration (if installed)

For persistent issues, check:
- `matrix-data/homeserver.log`
- Docker daemon logs
- System logs (Console.app on Mac, journalctl on Linux)
