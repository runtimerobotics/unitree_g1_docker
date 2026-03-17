from pathlib import Path


MESSAGES = {
    "setup.sh": "Setup unitree ros2 environment",
    "setup_local.sh": "Setup unitree ros2 simulation environment",
    "setup_default.sh": "Setup unitree ros2 environment with default interface",
}

NEEDLE = "source $HOME/unitree_ros2/cyclonedds_ws/install/setup.bash"


def patch_script(path: Path) -> None:
    text = path.read_text()
    if NEEDLE not in text:
        return

    if 'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' in text:
        path.write_text(text.replace("\n" + NEEDLE, ""))
        return

    replacement = """SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)"
CYCLONEDDS_SETUP="$SCRIPT_DIR/cyclonedds_ws/install/setup.bash"

echo "{message}"
source /opt/ros/foxy/setup.bash
if [ ! -f "$CYCLONEDDS_SETUP" ]; then
  echo "Missing Cyclone DDS workspace: $CYCLONEDDS_SETUP"
  echo "Build /workspace/src/unitree_ros2/cyclonedds_ws first."
  return 1 2>/dev/null || exit 1
fi
source "$CYCLONEDDS_SETUP" """.format(message=MESSAGES[path.name])

    lines = text.splitlines()
    suffix = "\n".join(lines[4:])
    new_text = "#!/bin/bash\n" + replacement + "\n" + suffix + "\n"
    path.write_text(new_text)


def main() -> None:
    repo_dir = Path("/workspace/src/unitree_ros2")
    if not repo_dir.exists():
        return

    for name in MESSAGES:
        path = repo_dir / name
        if path.exists():
            patch_script(path)


if __name__ == "__main__":
    main()
