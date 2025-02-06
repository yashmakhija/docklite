# Dockerlite System Documentation

This documentation explains how to use our custom Docker-like system with the base64 encoding/decoding service.

## System Requirements

- Linux operating system
- Root privileges
- Basic tools: curl, bash, unshare, chroot

## Directory Structure

```
.
├── dockerlite.sh          # Main container management script
├── app/
│   ├── Dockerfile          # Container definition for the base64 service
│   ├── package.json        # Node.js dependencies
│   └── server.js           # Express server implementation
└── containers/
```

## Installation

- Clone or create the project structure:

```bash
git clone https://github.com/your-repo/docker-lite.git
```

- Navigate to the project directory:

```bash
cd docker-lite
```

## Basic Commands

- List all available commands:

```bash
./docker-lite.sh
```

- Build an image:

```bash
sudo ./docker-lite.sh build app/Dockerfile
```

This will output an image ID - save it for the next step.

- List all images:

```bash
sudo ./docker-lite.sh images
```

- Run a container:

```bash
sudo ./docker-lite.sh run <image-id>
```

- List all containers:

```bash
sudo ./docker-lite.sh ps
```

- Remove a container:

```bash
sudo ./docker-lite.sh rm <container-id>
```

- Remove an image:

```bash
sudo ./docker-lite.sh rmi <image-id>
```

## Limitations

Current implementation has the following limitations:

- Basic network isolation
- No volume mounting
- Limited Dockerfile instruction support
- Basic environment variable handling
- No port mapping (uses host network)
- Limited container lifecycle management

## Example Workflow

### Build the base64 service:

```bash
sudo ./docker-lite.sh build app/Dockerfile
```

### Run the container:

```bash
sudo ./docker-lite.sh run <image-id>
```

### Test the service:

```bash
curl -X POST -d '{"text": "Hello, World!"}' http://localhost:3000/encode
```

### Clean up:

```bash
sudo ./docker-lite.sh rm <container-id>
sudo ./docker-lite.sh rmi <image-id>
```

For any additional features or improvements, please refer to the source code or request enhancements.
