#!/bin/bash

# Create a directory for our compose files if it doesn't exist
mkdir -p docker-compose-files
echo "Creating Docker Compose files in docker-compose-files directory..."

# 1. Create networks.yml
cat > docker-compose-files/networks.yml << 'EOF'
name: networks
networks:
  batserver_docker_network:
    name: batserver_docker_network
    external: true

  gluetun_network:
    name: gluetun_network
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/16
EOF
echo "✅ Created networks.yml"

# 2. Create media-management.yml
cat > docker-compose-files/media-management.yml << 'EOF'
name: media-management
services:
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.22
    volumes:
      - /tank/arr/radarr:/config
      - /tank/arr/data:/data
    ports:
      - "7878:7878"
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(`radarr.kasat.work`)"
      - "traefik.http.routers.radarr.entrypoints=web,websecure"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
  
  whisparr:
    container_name: whisparr
    image: ghcr.io/hotio/whisparr
    ports:
      - "6969:6969"
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
      # - UMASK=002
    volumes:
      - /tank/arr/whisparr:/config
      - /tank/arr/data:/data
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.29

  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.23
    ports:
      - "5055:5055"
    volumes:
      - /tank/arr/jellyseerr:/app/config
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    dns:
      - 8.8.8.8
      - 1.1.1.1
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyseerr.rule=Host(`jellyseerr.kasat.work`)"
      - "traefik.http.routers.jellyseerr.entrypoints=web,websecure"
      - "traefik.http.services.jellyseerr.loadbalancer.server.port=5055"

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.24
    volumes:
      - /tank/arr/sonarr:/config
      - /tank/arr/data:/data
    ports:
      - "8989:8989"
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(`sonarr.kasat.work`)"
      - "traefik.http.routers.sonarr.entrypoints=web,websecure"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"

networks:
  batserver_docker_network:
    external: true
  gluetun_network:
    external: true
EOF
echo "✅ Created media-management.yml"

# 3. Create download-clients.yml
cat > docker-compose-files/download-clients.yml << 'EOF'
name: download-clients
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - WEBUI_PORT=8787
      - TORRENTING_PORT=6881
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.27
    volumes:
      - /tank/arr/qbittorrent:/config
      - /tank/arr/data/torrents:/data/torrents
    ports:
      - "8787:8787"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.qbittorrent.rule=Host(`qbittorrent.kasat.work`)"
      - "traefik.http.routers.qbittorrent.entrypoints=web,websecure"
      - "traefik.http.services.qbittorrent.loadbalancer.server.port=8787"

  rflood:
    container_name: rflood
    image: ghcr.io/hotio/rflood
    ports:
      - "3001:3000"
      - "5000:5000"
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
      # - UMASK=002
      - FLOOD_AUTH=false
      - ARGS
      - FLOOD_ARGS
    networks:
      - batserver_docker_network
    volumes:
      - /tank/arr/rflood:/config
      - /tank/arr/data/torrents:/data

networks:
  batserver_docker_network:
    external: true
  gluetun_network:
    external: true
EOF
echo "✅ Created download-clients.yml"

# 4. Create media-servers.yml
cat > docker-compose-files/media-servers.yml << 'EOF'
name: media-servers
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    networks:
      - batserver_docker_network
    ports:
      - "8096:8096"
      - "8920:8920"
      - "7359:7359/udp"
      - "1900:1900/udp"
    volumes:
      - /tank/arr/jellyfin/config:/config
      - /tank/arr/jellyfin/cache:/cache
      - /tank/arr/data/media:/data/media
      - /tank/arr/jellyfin/fonts:/usr/local/share/fonts/custom:ro
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri  # Pass through the Intel GPU for hardware acceleration
    # group_add:
    #   - "render"  # Adds container user to the render group
    #   - "video"   # Ensures access to video acceleration
    privileged: true  # Optional, but sometimes needed for GPU access
    environment:
      - JELLYFIN_PublishedServerUrl=http://jellyfin.kasat.work
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.kasat.work`)"
      - "traefik.http.routers.jellyfin.entrypoints=web,websecure"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
      
  tdarr:
    container_name: tdarr
    image: ghcr.io/haveagitgat/tdarr:latest
    restart: unless-stopped
    networks:
      batserver_docker_network:
    ports:
      - 8265:8265 # webUI port
      - 8266:8266 # server port
    environment:
      - TZ=${TZ:-Asia/Kolkata}
      # - PUID=${PUID}
      # - PGID=${PGID}
      - UMASK_SET=002
      - serverIP=0.0.0.0
      - serverPort=8266
      - webUIPort=8265
      - internalNode=true
      - inContainer=true
      - ffmpegVersion=7
      - nodeName=MyInternalNode
    volumes:
      - /docker/tdarr/server:/app/server
      - /docker/tdarr/configs:/app/configs
      - /docker/tdarr/logs:/app/logs
      - /tank/arr/data:/media
      - /tank/arr/transcode_cache:/temp
    devices:
      - /dev/dri:/dev/dri
    deploy:
      resources:
        limits:
          cpus: 7.2

  tdarr-node:
    container_name: tdarr-node
    image: ghcr.io/haveagitgat/tdarr_node:latest
    restart: unless-stopped
    network_mode: service:tdarr
    environment:
      - TZ=${TZ:-Asia/Kolkata}
      # - PUID=${PUID}
      # - PGID=${PGID}
      - UMASK_SET=002
      - nodeName=MyExternalNode
      - serverIP=0.0.0.0
      - serverPort=8266
      - inContainer=true
      - ffmpegVersion=7
    volumes:
      - /docker/tdarr/configs:/app/configs
      - /docker/tdarr/logs:/app/logs
      - /tank/arr/data:/media
      - /tank/arr/transcode_cache:/temp
    devices:
      - /dev/dri:/dev/dri

networks:
  batserver_docker_network:
    external: true
EOF
echo "✅ Created media-servers.yml"

# 5. Create vpn.yml with environment variables
cat > docker-compose-files/vpn.yml << 'EOF'
name: vpn
services:
  gluetun:
    container_name: gluetun
    image: qmcgaw/gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - /tank/arr/gluetun:/gluetun
    environment:
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER}
      - VPN_TYPE=${VPN_TYPE}
      - OPENVPN_USER=${OPENVPN_USER}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD}
      - SERVER_COUNTRIES=${SERVER_COUNTRIES}
      - TZ=${TZ:-Asia/Kolkata}
      - BLOCK_MALICIOUS=off
      - BLOCK_SURVEILLANCE=off
      - BLOCK_ADS=off
      - DOT=off
      - UPDATER_PERIOD=3h
      # - SERVER_HOSTNAMES=
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.25
    ports:
      - "9696:9696"
      # - "8787:8787"
      # - "6881:6881"
      # - "6881:6881/udp"
    restart: on-failure:5
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=Host(`prowlarr.kasat.work`)"
      - "traefik.http.routers.prowlarr.entrypoints=web,websecure"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    volumes:
      - /tank/arr/prowlarr:/config
    network_mode: "service:gluetun"
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=${LOG_LEVEL:-info}
      - LOG_HTML=${LOG_HTML:-false}
      - CAPTCHA_SOLVER=${CAPTCHA_SOLVER:-none}
      - TZ=${TZ:-Asia/Kolkata}
    ports:
      - "${PORT:-8191}:8191"
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.26
    restart: unless-stopped

networks:
  batserver_docker_network:
    external: true
  gluetun_network:
    external: true
EOF
echo "✅ Created vpn.yml"

# 6. Create dashboards.yml with environment variables
cat > docker-compose-files/dashboards.yml << 'EOF'
name: dashboards
services:
  homarr:
    container_name: homarr
    image: ghcr.io/homarr-labs/homarr:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /tank/arr/homarr/appdata:/appdata
    environment:
      - SECRET_ENCRYPTION_KEY=${HOMARR_SECRET_ENCRYPTION_KEY}
      - TZ=${TZ:-Asia/Kolkata}
    ports:
      - "7575:7575"
    networks:
      batserver_docker_network:
      gluetun_network:
        ipv4_address: 172.22.0.28
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homarr.rule=Host(`homarr.kasat.work`)"
      - "traefik.http.routers.homarr.entrypoints=web,websecure"
      - "traefik.http.services.homarr.loadbalancer.server.port=7575"
    
  dashy:
    image: lissy93/dashy
    container_name: Dashy
    # volumes:
      # - /root/my-config.yml:/app/user-data/conf.yml
    ports:
      - 9080:8080
    environment:
      - NODE_ENV=production
      - TZ=${TZ:-Asia/Kolkata}
    restart: unless-stopped
    networks:
      batserver_docker_network:
    healthcheck:
      test: ['CMD', 'node', '/app/services/healthcheck']
      interval: 1m30s
      timeout: 10s
      retries: 3
      start_period: 40s

  homeassistant:
    image: lscr.io/linuxserver/homeassistant:latest
    container_name: homeassistant
    # Consider if you need host network mode or can use your existing network
    # network_mode: host 
    networks:
      - batserver_docker_network
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    volumes:
      - /tank/container_configs/homeassistant:/config
    ports:
      - 8123:8123
    # If you have specific devices, uncomment and update
    # devices:
    #   - /dev/ttyUSB0:/dev/ttyUSB0  # Example for a Z-Wave or Zigbee stick
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(`ha.kasat.work`)"
      - "traefik.http.routers.homeassistant.entrypoints=web,websecure"
      - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
      # Add middleware for proper header handling
      - "traefik.http.middlewares.homeassistant-headers.headers.customrequestheaders.X-Forwarded-For=true"
      - "traefik.http.middlewares.homeassistant-headers.headers.customrequestheaders.X-Forwarded-Proto=true"
      - "traefik.http.middlewares.homeassistant-headers.headers.customrequestheaders.X-Forwarded-Host=true"
      - "traefik.http.routers.homeassistant.middlewares=homeassistant-headers@docker"

networks:
  batserver_docker_network:
    external: true
  gluetun_network:
    external: true
EOF
echo "✅ Created dashboards.yml"

# 7. Create search-tools.yml
cat > docker-compose-files/search-tools.yml << 'EOF'
name: search-tools
services:
  hoarder:
    container_name: Hoarder
    image: ghcr.io/hoarder-app/hoarder:${HOARDER_VERSION:-release}
    restart: unless-stopped
    volumes:
      - /tank/arr/hoarder:/data
    ports:
      - 3000:3000
    env_file:
      - .env
    networks:
      batserver_docker_network:
    environment:
      MEILI_ADDR: http://meilisearch:7700
      BROWSER_WEB_URL: http://chrome:9222
      DATA_DIR: /data
      TZ: ${TZ:-Asia/Kolkata}

  chrome:
    container_name: chrome
    image: gcr.io/zenika-hub/alpine-chrome:123
    restart: unless-stopped
    networks:
      batserver_docker_network:
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    command:
      - --no-sandbox
      - --disable-gpu
      - --disable-dev-shm-usage
      - --remote-debugging-address=0.0.0.0
      - --remote-debugging-port=9222
      - --hide-scrollbars

  meilisearch:
    container_name: meilisearch
    image: getmeili/meilisearch:v1.11.1
    restart: unless-stopped
    env_file:
      - .env
    networks:
      batserver_docker_network:
    environment:
      MEILI_NO_ANALYTICS: "true"
      TZ: ${TZ:-Asia/Kolkata}
    volumes:
      - meilisearch:/meili_data

networks:
  batserver_docker_network:
    external: true

volumes:
  meilisearch:
  data:
EOF
echo "✅ Created search-tools.yml"

# 8. Create infra.yml with environment variables
cat > docker-compose-files/infra.yml << 'EOF'
name: infra
services:
  cloudflare-tunnel:
    container_name: cloudflare_tunnel
    networks:
      - batserver_docker_network
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run --token ${CLOUDFLARE_TUNNEL_TOKEN}
    restart: always
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    extra_hosts:
      - "host.docker.internal:host-gateway"

  portainer:
    image: portainer/portainer-ce:lts
    container_name: portainer
    restart: always
    ports:
      - "8000:8000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - batserver_docker_network
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.kasat.work`)"
      - "traefik.http.routers.portainer.entrypoints=web,websecure"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
  
  nginx-proxy:
    container_name: nginx-proxy
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    environment:
      - PUID=0
      - PGID=0
      - TZ=${TZ:-Asia/Kolkata}
    networks:
      - batserver_docker_network
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - /tank/container_configs/nginx-proxy/data:/data
      - /tank/container_configs/nginx-proxy/letsencrypt:/etc/letsencrypt
      
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=${TZ:-Asia/Kolkata}
      
  netbird:
    image: netbirdio/netbird:latest
    container_name: ${NETBIRD_PEER_NAME:-batserver}
    hostname: ${NETBIRD_PEER_NAME:-batserver}
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
    environment:
      - NB_SETUP_KEY=${NETBIRD_SETUP_KEY}
      - TZ=${TZ:-Asia/Kolkata}
    volumes:
      - netbird-client:/etc/netbird
    restart: unless-stopped
    networks:
      - batserver_docker_network
  autoheal:
    deploy:
      replicas: 1
    environment:
      AUTOHEAL_CONTAINER_LABEL: all
    image: willfarrell/autoheal:latest
    network_mode: none
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
  
  traefik:
    container_name: traefik
    image: traefik:latest
    networks:
      - batserver_docker_network
    command:
      # Dashboard
      - "--api=true"
      - "--api.dashboard=true"
      - "--api.insecure=true"  # Allow access to dashboard without auth at :8080/dashboard/
      # Docker provider
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      # File provider for static config
      - "--providers.file.directory=/etc/traefik/dynamic_conf"
      # Entry points
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      # Let's Encrypt
      - "--certificatesresolvers.letsencrypt.acme.email=sid.kasat@gmail.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/acme/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
    ports:
      - "80:80"
      - "443:443"
      # Dashboard port with original port mapping
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /tank/container_configs/traefik/acme:/etc/traefik/acme
      - /tank/container_configs/traefik/dynamic_conf:/etc/traefik/dynamic_conf
    labels:
      - "traefik.enable=true"
      # Dashboard accessible via hostname (optional)
      - "traefik.http.routers.traefik.rule=Host(`traefik.kasat.work`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
    restart: unless-stopped
    environment:
      - TZ=${TZ:-Asia/Kolkata}
  
  whoami:
    # Test container
    image: traefik/whoami
    networks:
      - batserver_docker_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.whoami.rule=Host(`whoami.kasat.work`)"
      - "traefik.http.routers.whoami.entrypoints=web,websecure"

networks:
  batserver_docker_network:
    name: batserver_docker_network
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.100.0/24

volumes:
  portainer_data:
  netbird-client:
EOF
echo "✅ Created infra.yml"

# 9. Create immich.yml with environment variables
cat > docker-compose-files/immich.yml << 'EOF'
name: immich
services:
  immich-server:
    container_name: immich_server
    networks:
      - batserver_docker_network
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /tank/immich/external:/imports/external
      - /tank/immich/uploads:/usr/src/app/upload
    env_file:
      - .env
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    ports:
      - "2283:2283"
    depends_on:
      - redis
      - database
    restart: always
    healthcheck:
      disable: false
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(`immich.kasat.work`)"
      - "traefik.http.routers.immich.entrypoints=web,websecure"
      - "traefik.http.services.immich.loadbalancer.server.port=2283"

  immich-machine-learning:
    container_name: immich_machine_learning
    networks:
      - batserver_docker_network
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    restart: always
    healthcheck:
      disable: false

  redis:
    container_name: immich_redis
    networks:
      - batserver_docker_network
    image: docker.io/redis:6.2-alpine@sha256:148bb5411c184abd288d9aaed139c98123eeb8824c5d3fce03cf721db58066d8
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    healthcheck:
      test: redis-cli ping || exit 1
    restart: always

  database:
    container_name: immich_postgres
    networks:
      - batserver_docker_network
    image: docker.io/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:739cdd626151ff1f796dc95a6591b55a714f341c737e27f045019ceabf8e8c52
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: "--data-checksums"
      TZ: ${TZ:-Asia/Kolkata}
    volumes:
      - /tank/database/immich:/var/lib/postgresql/data
    healthcheck:
      test: >-
        pg_isready --dbname="$${POSTGRES_DB}" --username="$${POSTGRES_USER}" || exit 1;
        Chksum="$$(psql --dbname="$${POSTGRES_DB}" --username="$${POSTGRES_USER}" --tuples-only --no-align
        --command='SELECT COALESCE(SUM(checksum_failures), 0) FROM pg_stat_database')";
        echo "checksum failure count is $$Chksum";
        [ "$$Chksum" = '0' ] || exit 1
      interval: 5m
      start_interval: 30s
      start_period: 5m
    command: >-
      postgres
      -c shared_preload_libraries=vectors.so
      -c 'search_path="$$user", public, vectors'
      -c logging_collector=on
      -c max_wal_size=2GB
      -c shared_buffers=512MB
      -c wal_compression=on
    restart: always
  
  nextcloud:
    image: lscr.io/linuxserver/nextcloud:latest
    container_name: nextcloud
    volumes:
      - /tank/nextcloud/config:/config
      - /tank/nextcloud/data:/data
      - /tank/arr/data/media/tv:/tv
      - /tank/arr/data/media/movies:/movies
    ports:
      - 7443:443
    networks:
      - batserver_docker_network
    environment:
      - TZ=${TZ:-Asia/Kolkata}
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`nextcloud.kasat.work`)"
      - "traefik.http.routers.nextcloud.entrypoints=web,websecure"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=443"
      - "traefik.http.middlewares.nextcloud-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-headers@docker"

networks:
  batserver_docker_network:
    name: batserver_docker_network
    external: true

volumes:
  model-cache:
EOF
echo "✅ Created immich.yml"

# Create Traefik dynamic configuration directory and files
mkdir -p /tank/container_configs/traefik/acme
mkdir -p /tank/container_configs/traefik/dynamic_conf

# Create a basic auth middleware file for Traefik dashboard protection
cat > /tank/container_configs/traefik/dynamic_conf/middleware.yml << 'EOF'
# Dynamic configuration for Traefik
http:
  middlewares:
    secured:
      chain:
        middlewares:
          - secure-headers
          - rate-limit
    
    secure-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        frameDeny: true
        sslRedirect: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
    
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        
    forwarded-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-For: "true"
          X-Forwarded-Host: "true"
          X-Forwarded-Proto: "true"
          X-Forwarded-Server: "true"
EOF

# Create TLS configuration
cat > /tank/container_configs/traefik/dynamic_conf/tls.yml << 'EOF'
# TLS configuration
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
EOF

echo "✅ Created Traefik configuration files"

# Create a helper script to start everything
cat > run_all.sh << 'EOF'
#!/bin/bash

# Start networks first
docker compose -f docker-compose-files/networks.yml up -d

# Short delay to ensure network is created
sleep 2

# Start infrastructure services
docker compose -f docker-compose-files/infra.yml up -d

# Start VPN services
docker compose -f docker-compose-files/vpn.yml up -d

# Start all other services
for file in docker-compose-files/*.yml; do
  if [[ "$file" != "docker-compose-files/networks.yml" && "$file" != "docker-compose-files/infra.yml" && "$file" != "docker-compose-files/vpn.yml" ]]; then
    echo "Starting services from $file..."
    docker compose -f "$file" up -d
  fi
done

echo "All services started!"
EOF
chmod +x run_all.sh
echo "✅ Created run_all.sh helper script"

echo "🎉 All Docker Compose files have been generated in the docker-compose-files directory."
echo "📝 Copy the updated .env file to the same directory as this script."
echo "🚀 Run './run_all.sh' to start all services in the correct order."