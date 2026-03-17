#!/bin/bash
set -euo pipefail

WORKSPACE_ROOT="/workspace"
SRC_DIR="$WORKSPACE_ROOT/src"
UNITREE_SDK2_DIR="$SRC_DIR/unitree_sdk2"
UNITREE_ROS2_DIR="$SRC_DIR/unitree_ros2"
CYCLONEDDS_WS_DIR="$UNITREE_ROS2_DIR/cyclonedds_ws"
CYCLONEDDS_SRC_DIR="$CYCLONEDDS_WS_DIR/src"
EXAMPLE_WS_DIR="$UNITREE_ROS2_DIR/example"

ensure_repo() {
  local url="$1"
  local ref="$2"
  local dest="$3"

  if [ -d "$dest/.git" ]; then
    return
  fi

  git clone --branch "$ref" --depth 1 "$url" "$dest"
}

ensure_line_in_file() {
  local line="$1"
  local file="$2"

  grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

ensure_conditional_source_in_file() {
  local script_path="$1"
  local file="$2"
  local legacy_line="source $script_path"
  local guarded_line="[ -f $script_path ] && source $script_path"

  if [ -f "$file" ]; then
    sed -i "\|^${legacy_line}$|d" "$file"
  fi

  ensure_line_in_file "$guarded_line" "$file"
}

source_setup_script() {
  local script_path="$1"
  local had_nounset=0

  if [ ! -f "$script_path" ]; then
    echo "Missing setup script: $script_path" >&2
    return 1
  fi

  case $- in
    *u*)
      had_nounset=1
      set +u
      ;;
  esac

  export AMENT_TRACE_SETUP_FILES="${AMENT_TRACE_SETUP_FILES-}"
  export AMENT_RETURN_ENVIRONMENT_HOOKS="${AMENT_RETURN_ENVIRONMENT_HOOKS-}"
  export COLCON_TRACE="${COLCON_TRACE-}"

  # shellcheck source=/dev/null
  source "$script_path"
  local status=$?

  if [ "$had_nounset" -eq 1 ]; then
    set -u
  fi

  return "$status"
}

patch_unitree_setup_scripts() {
  python3 /workspace/.devcontainer/patch_unitree_setup_scripts.py
}

build_unitree_sdk2() {
  cd "$UNITREE_SDK2_DIR"
  mkdir -p build
  cd build
  cmake ..
  make -j"$(nproc)"
  make install || true
}

build_unitree_ros2_for_foxy() {
  # Build Cyclone DDS using the same workspace/layout recommended by Unitree.
  mkdir -p "$CYCLONEDDS_SRC_DIR"
  cd "$CYCLONEDDS_SRC_DIR"
  ensure_repo "https://github.com/ros2/rmw_cyclonedds.git" "foxy" \
    "$CYCLONEDDS_SRC_DIR/rmw_cyclonedds"
  ensure_repo "https://github.com/eclipse-cyclonedds/cyclonedds.git" "releases/0.10.x" \
    "$CYCLONEDDS_SRC_DIR/cyclonedds"
  cd "$CYCLONEDDS_WS_DIR"

  # Foxy's Cyclone build is sensitive to a pre-sourced ROS environment.
  # If the build fails manually, the usual fallback is:
  # export LD_LIBRARY_PATH=/opt/ros/foxy/lib
  env -u AMENT_PREFIX_PATH \
      -u CMAKE_PREFIX_PATH \
      -u COLCON_PREFIX_PATH \
      -u LD_LIBRARY_PATH \
      -u PYTHONPATH \
      -u ROS_DISTRO \
      -u ROS_PYTHON_VERSION \
      -u ROS_VERSION \
      -u RMW_IMPLEMENTATION \
      LD_LIBRARY_PATH=/opt/ros/foxy/lib \
      colcon build --packages-select cyclonedds

  source_setup_script /opt/ros/foxy/setup.bash
  export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  colcon build --packages-select unitree_go unitree_hg unitree_api

  cd "$EXAMPLE_WS_DIR"
  source_setup_script /opt/ros/foxy/setup.bash
  source_setup_script "$CYCLONEDDS_WS_DIR/install/setup.bash"
  export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  colcon build --packages-select unitree_ros2_example
}

cd "$WORKSPACE_ROOT"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

if [ ! -d "$UNITREE_SDK2_DIR" ]; then
  git clone https://github.com/unitreerobotics/unitree_sdk2.git
fi

if [ ! -d "$UNITREE_ROS2_DIR" ]; then
  git clone https://github.com/unitreerobotics/unitree_ros2.git
fi

patch_unitree_setup_scripts

build_unitree_sdk2

ensure_line_in_file 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' ~/.bashrc
ensure_line_in_file 'export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp' ~/.bashrc
ensure_conditional_source_in_file '/workspace/src/unitree_ros2/cyclonedds_ws/install/setup.bash' ~/.bashrc
ensure_conditional_source_in_file '/workspace/src/unitree_ros2/example/install/setup.bash' ~/.bashrc

source_setup_script /opt/ros/foxy/setup.bash
rosdep install --from-paths "$UNITREE_ROS2_DIR/cyclonedds_ws/src/unitree" "$EXAMPLE_WS_DIR/src" \
  --ignore-src -r -y

build_unitree_ros2_for_foxy

echo "=== Setup Complete ==="
