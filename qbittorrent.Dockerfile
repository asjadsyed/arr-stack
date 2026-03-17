FROM lscr.io/linuxserver/qbittorrent:5.1.4@sha256:855e5f4805ac218f406a5ae989a62a77e03f7e5f70128335b7970550a58c96e1

COPY ./qBittorrent.conf /config/qBittorrent/qBittorrent.conf

COPY ./custom-cont-init.d/qbittorrent/ /custom-cont-init.d/
