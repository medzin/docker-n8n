# n8n Docker Image for Unraid

This repository provides a custom Docker image for [n8n](https://n8n.io/),
specifically designed for better compatibility with **Unraid** and other
systems where file permissions on mounted volumes can be problematic.

## Key Features

- **User/Group ID Mapping:** Supports `PUID` and `PGID` environment variables
  to run the n8n process with specific user and group IDs. This ensures that
  files created in your appdata share (e.g., `/data/.n8n`) are owned by your
  Unraid user, preventing permission issues.
- **Root Entrypoint:** The container starts as root to allow necessary
  initializations (like user modifications) and then steps down to the
  specified user using `su-exec`. This structure is also compatible with
  **Tailscale** integrations that require root access for setup.
- **Automated Updates:** A daily workflow checks for new stable n8n releases
  and automatically builds and publishes updated images to Docker Hub.

## Usage

### Docker CLI

```bash
docker run -d \
  --name n8n \
  -e PUID=99 \
  -e PGID=100 \
  -e UMASK=022 \
  -p 5678:5678 \
  -v /mnt/user/appdata/n8n:/data \
  medzin/n8n:latest
```

## Environment Variables

| Variable | Description                         | Default |
| :------- | :---------------------------------- | :------ |
| `PUID`   | User ID to run the n8n process as.  | `1000`  |
| `PGID`   | Group ID to run the n8n process as. | `1000`  |
| `UMASK`  | Umask for file creation.            | `022`   |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details.
