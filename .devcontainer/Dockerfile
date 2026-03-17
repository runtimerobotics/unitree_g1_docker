FROM osrf/ros:foxy-desktop

ENV DEBIAN_FRONTEND=noninteractive

# System + dev tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    nano \
    htop \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    libspdlog-dev \
    libyaml-cpp-dev \
    libgl1 \
    libegl1 \
    libx11-6 \
    net-tools \
    iputils-ping \
    mesa-utils \
    x11-apps \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# ROS dep manager
RUN rosdep init || true
RUN rosdep update

# Foxy needs the Cyclone RMW package plus the DDS IDL generator package.
RUN apt-get update && apt-get install -y \
    ros-foxy-rmw-cyclonedds-cpp \
    ros-foxy-rosidl-generator-dds-idl \
    && rm -rf /var/lib/apt/lists/*

# Workspace
WORKDIR /workspace
COPY . /workspace

# Auto-source ROS
RUN echo "source /opt/ros/foxy/setup.bash" >> /root/.bashrc

CMD ["/bin/bash"]
