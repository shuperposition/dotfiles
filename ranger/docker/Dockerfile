# Image used by ranger/{ranger,ranger-root}. Built by step_ranger_docker as
# nvidia/cuda:12.8.1-base-ubuntu24.04-sm.
FROM nvidia/cuda:12.8.1-base-ubuntu24.04
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ranger && \
    rm -rf /var/lib/apt/lists/*
ENV TERM=xterm-256color
