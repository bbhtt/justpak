FROM ghcr.io/flathub-infra/flatpak-builder-lint:latest-amd64
ADD passwd /etc/passwd
RUN install -d -m755 -o 1000 -g 1000 /home/flatbld
USER flatbld
