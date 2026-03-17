# Unitree G1 Docker Dev Environment

This repository provides a ROS 2 Foxy development container for Unitree G1 work with:

- `unitree_sdk2`
- `unitree_ros2`
- Cyclone DDS / `rmw_cyclonedds_cpp`
- X11 GUI forwarding
- NVIDIA GPU access

It supports two ways of working:

- VS Code Dev Containers
- Plain Docker Compose from the terminal

## What This Setup Does

The container is built from `osrf/ros:foxy-desktop` and is configured to:

- use `host` networking
- run as a privileged container
- expose all NVIDIA GPUs
- forward X11 applications to the host display
- clone and build the Unitree SDK and ROS 2 packages during post-create setup

When setup completes, the container shell is prepared to use:

- `/opt/ros/foxy/setup.bash`
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`
- the built Unitree workspaces under `/workspace/src/unitree_ros2`

## Prerequisites

Make sure the host machine has:

- Docker Engine
- Docker Compose v2
- NVIDIA drivers installed
- NVIDIA Container Toolkit installed and working with Docker
- an X11 desktop session, or XWayland if you are on Wayland
- VS Code with the `Dev Containers` extension if you want the IDE workflow

If Docker is not installed yet, you can use the host-side helper script in [scripts/setup_docker_ubuntu.sh](/home/robot/g1_docker/scripts/setup_docker_ubuntu.sh#L1C1).

Useful host-side checks:

```bash
docker --version
docker compose version
nvidia-smi
echo $DISPLAY
echo $XAUTHORITY
```

## Install Docker on Ubuntu

This repository includes a helper script for installing:

- Docker Engine
- Docker Compose plugin
- NVIDIA Container Toolkit when an NVIDIA driver is already present

Run it on the Ubuntu host, not inside the container:

```bash
chmod +x scripts/setup_docker_ubuntu.sh
./scripts/setup_docker_ubuntu.sh
```

After the script finishes, log out and log back in if Docker group membership has not taken effect yet, then verify:

```bash
docker --version
docker compose version
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
```

## Repository Layout

- `docker-compose.yml`: main container runtime configuration
- `.devcontainer/Dockerfile`: image definition
- `.devcontainer/devcontainer.json`: VS Code dev container config
- `.devcontainer/post_create.sh`: clones dependencies and builds the workspace

## Before Starting

Allow the container to access your X server.

Recommended:

```bash
xhost +SI:localuser:root
```

Fallback if needed:

```bash
xhost +local:root
```

If your host session uses a custom Xauthority path, this project will automatically mount the value from your current `XAUTHORITY` environment variable.

## Option 1: Start With VS Code Dev Containers

1. Open this repository in VS Code.
2. Install the `Dev Containers` extension if it is not already installed.
3. Run `Dev Containers: Reopen in Container`.
4. Wait for the image build and container startup to finish.
5. Wait for the post-create step to finish. This step:
   - clones `unitree_sdk2`
   - clones `unitree_ros2`
   - installs ROS dependencies with `rosdep`
   - builds the Unitree SDK
   - builds Cyclone DDS and Unitree ROS 2 packages

The first startup can take a while because it performs a full dependency setup and build.

Once the container is ready, open a terminal in VS Code and verify:

```bash
printenv | grep -E 'ROS_DOMAIN_ID|RMW_IMPLEMENTATION|DISPLAY|XAUTHORITY'
```

Optional GUI and GPU checks:

```bash
xeyes
glxinfo | grep "OpenGL renderer"
nvidia-smi
```

## Option 2: Start With Docker Compose

Build and start the container:

```bash
docker compose up --build -d
```

Open a shell inside the running container:

```bash
docker exec -it unitree_dev bash
```

If you want to manually run the same setup used by the dev container:

```bash
bash .devcontainer/post_create.sh
```

This script is safe for repeated use in normal development because it checks for existing repositories before cloning them.

## Rebuild or Restart

Rebuild the image:

```bash
docker compose build --no-cache
```

Restart the container:

```bash
docker compose down
docker compose up -d
```

Stop and remove the container:

```bash
docker compose down
```

## Daily Development

Start a shell:

```bash
docker exec -it unitree_dev bash
```

Source ROS 2 manually if needed:

```bash
source /opt/ros/foxy/setup.bash
```

The container setup also appends the following to the shell environment:

- `LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`
- Unitree workspace setup scripts when they exist

## Quick Verification

Inside the container:

```bash
echo $DISPLAY
echo $XAUTHORITY
ros2 --help
nvidia-smi
```

Test X11:

```bash
xeyes
```

Test OpenGL:

```bash
glxinfo | grep "OpenGL renderer"
```

## Troubleshooting

### X11: "could not connect to display"

Check:

```bash
echo $DISPLAY
echo $XAUTHORITY
ls -l /tmp/.X11-unix
ls -l "$XAUTHORITY"
```

Then re-allow local root access on the host:

```bash
xhost +SI:localuser:root
```

If that still fails:

```bash
xhost +local:root
```

After changing host X11 permissions, restart the container:

```bash
docker compose down
docker compose up -d
```

### NVIDIA: GPU not visible in container

Check on the host:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
```

If the second command fails, the NVIDIA Container Toolkit is not configured correctly on the host yet.

### Post-create build takes a long time

The first run builds several ROS and DDS components from source. This is expected.

If a build fails, re-enter the container and rerun:

```bash
bash .devcontainer/post_create.sh
```

## Notes

- This setup uses `network_mode: host`, which is commonly needed for robotics workflows.
- This setup uses `privileged: true`, which gives the container elevated access to the host.
- GUI forwarding here is based on X11, not native Wayland.

## Useful Commands

```bash
docker compose up --build -d
docker compose down
docker exec -it unitree_dev bash
bash .devcontainer/post_create.sh
xhost +SI:localuser:root
```
