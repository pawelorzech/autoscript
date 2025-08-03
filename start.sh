```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=
log(){ printf '\n[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }; }

install_node_and_gemini(){
  log "Node.js LTS + gemini-cli"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get update
  apt-get install -y nodejs build-essential
  npm install -g @google/gemini-cli
}

install_base_tools(){
  log "Base packages, sops, age"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server ufw jq curl wget dnsutils nmap git make \
    sops age aide logwatch auditd unattended-upgrades \
    crowdsec crowdsec-firewall-bouncer-nftables
  systemctl enable ssh
}

bootstrap_sops(){
  log "Bootstrap sops + age"
  mkdir -p /root/.config/sops/age
  if [[ ! -f /root/.config/sops/age/keys.txt ]]; then
    age-keygen -o /root/.config/sops/age/keys.txt >/dev/null
  fi
  AGE_PUB=$(grep -m1 'public key:' /root/.config/sops/age/keys.txt | awk '{print $4}')
  install -d -m 700 /opt/services
  cat > /opt/services/.sops.yaml <<EOF
creation_rules:
  - path_regex: secrets/.*\\.sops$
    age: ["$AGE_PUB"]
EOF
}

create_admin_user(){
  log "Admin user, sudo, TOTP"
  groupadd -f admin
  id -u admin >/dev/null 2>&1 || useradd -m -s /bin/bash -G admin,sudo admin
  install -d -m 700 -o admin -g admin /home/admin/.ssh
  printf '%s\n' "$PUBLIC_KEY" > /home/admin/.ssh/authorized_keys
  chown admin:admin /home/admin/.ssh/authorized_keys
  chmod 600 /home/admin/.ssh/authorized_keys
  DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-google-authenticator
  sed -i '/pam_google_authenticator/d' /etc/pam.d/sudo
  sed -i '1iauth required pam_google_authenticator.so nullok' /etc/pam.d/sudo
  echo "%admin ALL=(ALL) ALL" > /etc/sudoers.d/90-admin
  chmod 440 /etc/sudoers.d/90-admin
  sudo -u admin google-authenticator -t -d -f -r 3 -R 30 -W
}

harden_ssh(){
  log "SSH hardening"
  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -q
  ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" -q
  rm -f /etc/ssh/ssh_host_dsa_key* /etc/ssh/ssh_host_ecdsa_key*
  SSH_PORT=$(shuf -i 10000-65535 -n 1)
  echo "$SSH_PORT" > /root/ssh_port.txt
  install -d /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/01-hardening.conf <<EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
Banner /etc/ssh/banner
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups admin sudo
EOF
  cat > /etc/ssh/banner <<'EOF'
******************************************************************
* Authorized users only. Activity is monitored and logged.       *
******************************************************************
EOF
  systemctl restart ssh
}

configure_firewall(){
  log "UFW + DOCKER-USER"
  SSH_PORT=$(cat /root/ssh_port.txt)
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "$SSH_PORT"/tcp
  ufw allow 80,443/tcp
  ufw allow 25,465,587,110,995,143,993,4190/tcp
  ufw allow 41641/udp
  ufw allow from 127.0.0.0/8 to any port 53 proto udp
  ufw --force enable
  # DOCKER-USER chain lockdown
  iptables -C DOCKER-USER -j RETURN 2>/dev/null || {
    iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -I DOCKER-USER -p tcp -m multiport --dports 80,443,25,465,587,110,995,143,993,4190 -j ACCEPT
    iptables -I DOCKER-USER -p tcp --dport "$SSH_PORT" -j ACCEPT
    iptables -A DOCKER-USER -j DROP
  }
}

system_baseline(){
  log "Kernel, journald, AIDE, unattended-upgrades"
  cat > /etc/sysctl.d/99-security.conf <<'EOF'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
  sysctl --system
  aideinit && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  printf 'Unattended-Upgrade::Automatic-Reboot "false";\n' > /etc/apt/apt.conf.d/50unattended-upgrades
  printf 'Unattended-Upgrade::Mail "%s";\n' "$ADMIN_EMAIL" >> /etc/apt/apt.conf.d/50unattended-upgrades
  install -d /etc/systemd/journald.conf.d
  cat > /etc/systemd/journald.conf.d/99-storage.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=1G
SystemMaxFileSize=128M
MaxRetentionSec=1month
EOF
  systemctl restart systemd-journald
}

install_docker(){
  log "Docker Engine + compose plugin"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker admin
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-address-pools": [{ "base": "10.88.0.0/16", "size": 24 }],
  "experimental": false
}
EOF
  systemctl enable docker
  systemctl restart docker
}

#-------------------------------#
# Secrets (sops managed)        #
#-------------------------------#
generate_random(){
  # urlsafe, no newline
  head -c 48 /dev/urandom | base64 | tr -d '\n' | tr '/+' 'AB'
}

write_sops_file_env(){
  # args: path key=value lines (plaintext via heredoc), encrypt in place
  local path="$1"; shift
  install -d "$(dirname "$path")"
  umask 077
  cat > "$path" <<EOF
$*
EOF
  sops -e -i "$path"
}

write_sops_file_blob(){
  # args: path content
  local path="$1"; shift
  install -d "$(dirname "$path")"
  umask 077
  printf '%s' "$*" > "$path"
  sops -e -i "$path"
}

prepare_secrets(){
  log "Prepare encrypted secrets with sops"
  # Traefik env
  write_sops_file_env /opt/services/traefik/secrets/traefik.env.sops \
"CF_DNS_API_TOKEN=$CF_DNS_API_TOKEN
ADMIN_EMAIL=$ADMIN_EMAIL
PRIMARY_DOMAIN=$PRIMARY_DOMAIN
TZ=$TIMEZONE"
  # Monitoring env (Grafana admin password auto if missing)
  : "${GRAFANA_ADMIN_PASSWORD:=$(generate_random)}"
  write_sops_file_env /opt/services/monitoring/secrets/monitoring.env.sops \
"GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
TZ=$TIMEZONE"
  # Alertmanager SMTP password as file secret
  : "${ALERT_SMTP_PASS:=$(generate_random)}"
  write_sops_file_blob /opt/services/monitoring/alertmanager/secrets/smtp_pass.sops "$ALERT_SMTP_PASS"

  # scrub process env copies
  unset CF_DNS_API_TOKEN GRAFANA_ADMIN_PASSWORD ALERT_SMTP_PASS
}

#-------------------------------#
# Traefik                       #
#-------------------------------#
deploy_traefik(){
  log "Traefik"
  install -d /opt/services/traefik/{data,config,dynamic,secrets}
  install -m 600 /dev/null /opt/services/traefik/data/acme.json || true
  ( docker network create traefik_proxy >/dev/null 2>&1 || true )

  cat > /opt/services/traefik/config/traefik.yml <<'EOF'
api: { dashboard: true }
ping: {}
entryPoints:
  web:
    address: ":80"
    http: { redirections: { entryPoint: { to: websecure, scheme: https } } }
  websecure:
    address: ":443"
providers:
  file: { directory: "/etc/traefik/dynamic", watch: true }
  docker:
    exposedByDefault: false
    network: traefik_proxy
certificatesResolvers:
  le-dns:
    acme:
      email: ${ADMIN_EMAIL}
      storage: /acme/acme.json
      dnsChallenge: { provider: cloudflare, delayBeforeCheck: 0 }
metrics: { prometheus: { addEntryPointsLabels: true, addServicesLabels: true } }
log: { level: INFO, format: json }
accessLog: { format: json }
EOF

  cat > /opt/services/traefik/dynamic/middlewares.yml <<'EOF'
http:
  middlewares:
    security-headers:
      headers:
        stsSeconds: 63072000
        stsIncludeSubdomains: true
        stsPreload: true
        contentTypeNosniff: true
        referrerPolicy: "strict-origin-when-cross-origin"
        frameDeny: true
        browserXssFilter: true
    gzip: { compress: {} }
    rate-limit:
      rateLimit: { burst: 100, average: 50 }
EOF

  cat > /opt/services/traefik/dynamic/tls.yml <<'EOF'
tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
EOF

  cat > /opt/services/traefik/versions.env <<EOF
TRAEFIK_VER=$TRAEFIK_VER
ADMIN_EMAIL=$ADMIN_EMAIL
EOF

  cat > /opt/services/traefik/docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:${TRAEFIK_VER}
    container_name: traefik
    restart: unless-stopped
    networks: [traefik_proxy]
    ports: ["80:80","443:443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - ./data/acme.json:/acme/acme.json
    environment:
      CF_DNS_API_TOKEN: ${CF_DNS_API_TOKEN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    cap_add: [NET_BIND_SERVICE]
    healthcheck:
      test: ["CMD","wget","--no-verbose","--tries=1","--spider","http://localhost:8080/ping"]
      interval: 30s
      timeout: 3s
      retries: 5
networks:
  traefik_proxy:
    external: true
EOF

  # sops - secure launch (no plaintext .env on disk)
  ( cd /opt/services/traefik && \
    sops exec-file --no-fifo ./secrets/traefik.env.sops \
    'docker compose --env-file ./versions.env --env-file {} up -d' )
}

#-------------------------------#
# Monitoring stack              #
#-------------------------------#
deploy_monitoring(){
  log "Monitoring: Prometheus, Grafana, Alertmanager, exporters"
  install -d /opt/services/monitoring/{prometheus/rules,grafana/provisioning/{datasources,dashboards},blackbox,alertmanager/secrets,secrets}

  # Prometheus config
  cat > /opt/services/monitoring/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - "/etc/prometheus/rules/*.yml"
alerting:
  alertmanagers:
    - static_configs: [{ targets: ['alertmanager:9093'] }]
scrape_configs:
  - job_name: prometheus
    static_configs: [{ targets: ['localhost:9090'] }]
  - job_name: node-exporter
    static_configs: [{ targets: ['node-exporter:9100'] }]
  - job_name: cadvisor
    static_configs: [{ targets: ['cadvisor:8080'] }]
  - job_name: traefik
    static_configs: [{ targets: ['traefik:8080'] }]
  - job_name: blackbox
    metrics_path: /probe
    params: { module: [http_2xx] }
    static_configs:
      - targets:
        - https://forum.yeswas.pl
        - https://social.ovh
        - https://rss.social.ovh
        - https://pawelorzech.pl
        - https://dash.orzech.me
        - https://run.orzech.me
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
EOF

  cat > /opt/services/monitoring/prometheus/rules/alerts.yml <<'EOF'
groups:
- name: general.rules
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 2m
    labels: { severity: critical }
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} down >2m"
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100) > 80
    for: 5m
    labels: { severity: warning }
    annotations: { summary: "High CPU {{ $labels.instance }}" }
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes*100 > 90
    for: 5m
    labels: { severity: warning }
    annotations: { summary: "High memory {{ $labels.instance }}" }
  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}/node_filesystem_size_bytes) < 0.1
    for: 10m
    labels: { severity: warning }
    annotations: { summary: "Low disk {{ $labels.instance }}" }
  - alert: CertificateExpiration
    expr: probe_ssl_earliest_cert_expiry - time() < 604800
    for: 0m
    labels: { severity: warning }
    annotations: { summary: "Cert expires soon {{ $labels.instance }}" }
EOF

  # Blackbox config
  cat > /opt/services/monitoring/blackbox/blackbox.yml <<'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1","HTTP/2.0"]
      valid_status_codes: [200,301,302]
      method: GET
      follow_redirects: true
      tls_config: { insecure_skip_verify: false }
EOF

  # Alertmanager config with file-based password
  cat > /opt/services/monitoring/alertmanager/alertmanager.yml <<EOF
global:
  smtp_smarthost: '$ALERT_SMTP_HOST'
  smtp_from: '$ALERT_SMTP_FROM'
  smtp_auth_username: '$ALERT_SMTP_USER'
  smtp_auth_password_file: '/etc/alertmanager/secrets/smtp_pass'
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'
receivers:
- name: 'email'
  email_configs:
  - to: '$ADMIN_EMAIL'
    subject: 'Alert: {{ "{{" }} .GroupLabels.alertname {{ "}}" }}'
    send_resolved: true
EOF

  # Grafana provisioning
  cat > /opt/services/monitoring/grafana/provisioning/datasources/prometheus.yml <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

  # Versions file
  cat > /opt/services/monitoring/versions.env <<EOF
PROMETHEUS_VER=$PROMETHEUS_VER
NODE_EXPORTER_VER=$NODE_EXPORTER_VER
CADVISOR_VER=$CADVISOR_VER
BLACKBOX_VER=$BLACKBOX_VER
GRAFANA_VER=$GRAFANA_VER
ALERTMANAGER_VER=$ALERTMANAGER_VER
EOF

  # Compose
  cat > /opt/services/monitoring/docker-compose.yml <<'EOF'
networks:
  monitoring:
  traefik_proxy:
    external: true
services:
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VER}
    container_name: prometheus
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=30d
      - --web.enable-lifecycle
      - --web.external-url=https://prometheus.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.prom.rule=Host(`prometheus.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.prom.entrypoints=websecure
      - traefik.http.routers.prom.tls.certresolver=le-dns
      - traefik.http.routers.prom.middlewares=security-headers@file

  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VER}
    container_name: node-exporter
    restart: unless-stopped
    networks: [monitoring]
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - --path.procfs=/host/proc
      - --path.rootfs=/rootfs
      - --path.sysfs=/host/sys
      - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
    security_opt: [no-new-privileges:true]
    read_only: true
    cap_drop: [ALL]

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:${CADVISOR_VER}
    container_name: cadvisor
    restart: unless-stopped
    networks: [monitoring]
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    privileged: true
    devices: ["/dev/kmsg:/dev/kmsg"]

  blackbox-exporter:
    image: prom/blackbox-exporter:${BLACKBOX_VER}
    container_name: blackbox-exporter
    restart: unless-stopped
    networks: [monitoring]
    volumes:
      - ./blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml:ro
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]

  alertmanager:
    image: prom/alertmanager:${ALERTMANAGER_VER}
    container_name: alertmanager
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
      - ${ALERT_SMTP_PASS_PATH}:/etc/alertmanager/secrets/smtp_pass:ro
    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
      - --web.external-url=https://alertmanager.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.alert.rule=Host(`alertmanager.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.alert.entrypoints=websecure
      - traefik.http.routers.alert.tls.certresolver=le-dns
      - traefik.http.routers.alert.middlewares=security-headers@file

  grafana:
    image: grafana/grafana:${GRAFANA_VER}
    container_name: grafana
    user: "472"
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_ROOT_URL: https://grafana.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:3000/api/health"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`grafana.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.grafana.entrypoints=websecure
      - traefik.http.routers.grafana.tls.certresolver=le-dns
      - traefik.http.routers.grafana.middlewares=security-headers@file

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF

  # secure launch: 1) create temp file for smtp pass, 2) inject env via monitoring.env.sops
  (
    cd /opt/services/monitoring
    sops exec-file --no-fifo ./alertmanager/secrets/smtp_pass.sops \
      'ALERT_SMTP_PASS_PATH={} sops exec-file --no-fifo ./secrets/monitoring.env.sops \
        "docker compose --env-file ./versions.env --env-file {} up -d"'
  )
}

main(){
  ensure_root
  timedatectl set-timezone "$TIMEZONE"
  install_node_and_gemini
  install_base_tools
  bootstrap_sops
  create_admin_user
  harden_ssh
  configure_firewall
  system_baseline
  install_docker
  prepare_secrets
  deploy_traefik
  deploy_monitoring
  log "Base ready - secrets via sops, no plaintext .env, Grafana no fallback password, Alertmanager password via file."
}

main "$@"
```

	'

#=============================#
# CONFIGURATION               #
#=============================#
# Sprawdź, czy plik konfiguracyjny istnieje i go wczytaj
if [[ ! -f autoscript.conf ]]; then
  echo "Błąd: Plik konfiguracyjny 'autoscript.conf' nie został znaleziony."
  echo "Skopiuj 'autoscript.conf.example' do 'autoscript.conf' i uzupełnij go."
  exit 1
fi
source autoscript.conf

# Sprawdź, czy wymagane zmienne są ustawione
: "${PUBLIC_KEY:?Ustaw PUBLIC_KEY w pliku autoscript.conf}"
: "${CF_DNS_API_TOKEN:?Ustaw CF_DNS_API_TOKEN w pliku autoscript.conf}"

#=============================#
# HELPER FUNCTIONS            #
#=============================#
log(){ printf '\n[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
ensure_root(){ [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }; }

install_node_and_gemini(){
  log "Node.js LTS + gemini-cli"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get update
  apt-get install -y nodejs build-essential
  npm install -g @google/gemini-cli
}

install_base_tools(){
  log "Base packages, sops, age"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    openssh-server ufw jq curl wget dnsutils nmap git make \
    sops age aide logwatch auditd unattended-upgrades \
    crowdsec crowdsec-firewall-bouncer-nftables
  systemctl enable ssh
}

bootstrap_sops(){
  log "Bootstrap sops + age"
  mkdir -p /root/.config/sops/age
  if [[ ! -f /root/.config/sops/age/keys.txt ]]; then
    age-keygen -o /root/.config/sops/age/keys.txt >/dev/null
  fi
  AGE_PUB=$(grep -m1 'public key:' /root/.config/sops/age/keys.txt | awk '{print $4}')
  install -d -m 700 /opt/services
  cat > /opt/services/.sops.yaml <<EOF
creation_rules:
  - path_regex: secrets/.*\\.sops$
    age: ["$AGE_PUB"]
EOF
}

create_admin_user(){
  log "Admin user, sudo, TOTP"
  groupadd -f admin
  id -u admin >/dev/null 2>&1 || useradd -m -s /bin/bash -G admin,sudo admin
  install -d -m 700 -o admin -g admin /home/admin/.ssh
  printf '%s\n' "$PUBLIC_KEY" > /home/admin/.ssh/authorized_keys
  chown admin:admin /home/admin/.ssh/authorized_keys
  chmod 600 /home/admin/.ssh/authorized_keys
  DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-google-authenticator
  sed -i '/pam_google_authenticator/d' /etc/pam.d/sudo
  sed -i '1iauth required pam_google_authenticator.so nullok' /etc/pam.d/sudo
  echo "%admin ALL=(ALL) ALL" > /etc/sudoers.d/90-admin
  chmod 440 /etc/sudoers.d/90-admin
  sudo -u admin google-authenticator -t -d -f -r 3 -R 30 -W
}

harden_ssh(){
  log "SSH hardening"
  ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -q
  ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" -q
  rm -f /etc/ssh/ssh_host_dsa_key* /etc/ssh/ssh_host_ecdsa_key*
  SSH_PORT=$(shuf -i 10000-65535 -n 1)
  echo "$SSH_PORT" > /root/ssh_port.txt
  install -d /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/01-hardening.conf <<EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding no
Banner /etc/ssh/banner
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups admin sudo
EOF
  cat > /etc/ssh/banner <<'EOF'
******************************************************************
* Authorized users only. Activity is monitored and logged.       *
******************************************************************
EOF
  systemctl restart ssh
}

configure_firewall(){
  log "UFW + DOCKER-USER"
  SSH_PORT=$(cat /root/ssh_port.txt)
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "$SSH_PORT"/tcp
  ufw allow 80,443/tcp
  ufw allow 25,465,587,110,995,143,993,4190/tcp
  ufw allow 41641/udp
  ufw allow from 127.0.0.0/8 to any port 53 proto udp
  ufw --force enable
  # DOCKER-USER chain lockdown
  iptables -C DOCKER-USER -j RETURN 2>/dev/null || {
    iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -I DOCKER-USER -p tcp -m multiport --dports 80,443,25,465,587,110,995,143,993,4190 -j ACCEPT
    iptables -I DOCKER-USER -p tcp --dport "$SSH_PORT" -j ACCEPT
    iptables -A DOCKER-USER -j DROP
  }
}

system_baseline(){
  log "Kernel, journald, AIDE, unattended-upgrades"
  cat > /etc/sysctl.d/99-security.conf <<'EOF'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
  sysctl --system
  aideinit && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  printf 'Unattended-Upgrade::Automatic-Reboot "false";\n' > /etc/apt/apt.conf.d/50unattended-upgrades
  printf 'Unattended-Upgrade::Mail "%s";\n' "$ADMIN_EMAIL" >> /etc/apt/apt.conf.d/50unattended-upgrades
  install -d /etc/systemd/journald.conf.d
  cat > /etc/systemd/journald.conf.d/99-storage.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=1G
SystemMaxFileSize=128M
MaxRetentionSec=1month
EOF
  systemctl restart systemd-journald
}

install_docker(){
  log "Docker Engine + compose plugin"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker admin
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-address-pools": [{ "base": "10.88.0.0/16", "size": 24 }],
  "experimental": false
}
EOF
  systemctl enable docker
  systemctl restart docker
}

#-------------------------------#
# Secrets (sops managed)        #
#-------------------------------#
generate_random(){
  # urlsafe, no newline
  head -c 48 /dev/urandom | base64 | tr -d '\n' | tr '/+' 'AB'
}

write_sops_file_env(){
  # args: path key=value lines (plaintext via heredoc), encrypt in place
  local path="$1"; shift
  install -d "$(dirname "$path")"
  umask 077
  cat > "$path" <<EOF
$*
EOF
  sops -e -i "$path"
}

write_sops_file_blob(){
  # args: path content
  local path="$1"; shift
  install -d "$(dirname "$path")"
  umask 077
  printf '%s' "$*" > "$path"
  sops -e -i "$path"
}

prepare_secrets(){
  log "Prepare encrypted secrets with sops"
  # Traefik env
  write_sops_file_env /opt/services/traefik/secrets/traefik.env.sops \
"CF_DNS_API_TOKEN=$CF_DNS_API_TOKEN
ADMIN_EMAIL=$ADMIN_EMAIL
PRIMARY_DOMAIN=$PRIMARY_DOMAIN
TZ=$TIMEZONE"
  # Monitoring env (Grafana admin password auto if missing)
  : "${GRAFANA_ADMIN_PASSWORD:=$(generate_random)}"
  write_sops_file_env /opt/services/monitoring/secrets/monitoring.env.sops \
"GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
TZ=$TIMEZONE"
  # Alertmanager SMTP password as file secret
  : "${ALERT_SMTP_PASS:=$(generate_random)}"
  write_sops_file_blob /opt/services/monitoring/alertmanager/secrets/smtp_pass.sops "$ALERT_SMTP_PASS"

  # scrub process env copies
  unset CF_DNS_API_TOKEN GRAFANA_ADMIN_PASSWORD ALERT_SMTP_PASS
}

#-------------------------------#
# Traefik                       #
#-------------------------------#
deploy_traefik(){
  log "Traefik"
  install -d /opt/services/traefik/{data,config,dynamic,secrets}
  install -m 600 /dev/null /opt/services/traefik/data/acme.json || true
  ( docker network create traefik_proxy >/dev/null 2>&1 || true )

  cat > /opt/services/traefik/config/traefik.yml <<'EOF'
api: { dashboard: true }
ping: {}
entryPoints:
  web:
    address: ":80"
    http: { redirections: { entryPoint: { to: websecure, scheme: https } } }
  websecure:
    address: ":443"
providers:
  file: { directory: "/etc/traefik/dynamic", watch: true }
  docker:
    exposedByDefault: false
    network: traefik_proxy
certificatesResolvers:
  le-dns:
    acme:
      email: ${ADMIN_EMAIL}
      storage: /acme/acme.json
      dnsChallenge: { provider: cloudflare, delayBeforeCheck: 0 }
metrics: { prometheus: { addEntryPointsLabels: true, addServicesLabels: true } }
log: { level: INFO, format: json }
accessLog: { format: json }
EOF

  cat > /opt/services/traefik/dynamic/middlewares.yml <<'EOF'
http:
  middlewares:
    security-headers:
      headers:
        stsSeconds: 63072000
        stsIncludeSubdomains: true
        stsPreload: true
        contentTypeNosniff: true
        referrerPolicy: "strict-origin-when-cross-origin"
        frameDeny: true
        browserXssFilter: true
    gzip: { compress: {} }
    rate-limit:
      rateLimit: { burst: 100, average: 50 }
EOF

  cat > /opt/services/traefik/dynamic/tls.yml <<'EOF'
tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
EOF

  cat > /opt/services/traefik/versions.env <<EOF
TRAEFIK_VER=$TRAEFIK_VER
ADMIN_EMAIL=$ADMIN_EMAIL
EOF

  cat > /opt/services/traefik/docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:${TRAEFIK_VER}
    container_name: traefik
    restart: unless-stopped
    networks: [traefik_proxy]
    ports: ["80:80","443:443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - ./data/acme.json:/acme/acme.json
    environment:
      CF_DNS_API_TOKEN: ${CF_DNS_API_TOKEN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    cap_add: [NET_BIND_SERVICE]
    healthcheck:
      test: ["CMD","wget","--no-verbose","--tries=1","--spider","http://localhost:8080/ping"]
      interval: 30s
      timeout: 3s
      retries: 5
networks:
  traefik_proxy:
    external: true
EOF

  # sops - secure launch (no plaintext .env on disk)
  ( cd /opt/services/traefik && \
    sops exec-file --no-fifo ./secrets/traefik.env.sops \
    'docker compose --env-file ./versions.env --env-file {} up -d' )
}

#-------------------------------#
# Monitoring stack              #
#-------------------------------#
deploy_monitoring(){
  log "Monitoring: Prometheus, Grafana, Alertmanager, exporters"
  install -d /opt/services/monitoring/{prometheus/rules,grafana/provisioning/{datasources,dashboards},blackbox,alertmanager/secrets,secrets}

  # Prometheus config
  cat > /opt/services/monitoring/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
rule_files:
  - "/etc/prometheus/rules/*.yml"
alerting:
  alertmanagers:
    - static_configs: [{ targets: ['alertmanager:9093'] }]
scrape_configs:
  - job_name: prometheus
    static_configs: [{ targets: ['localhost:9090'] }]
  - job_name: node-exporter
    static_configs: [{ targets: ['node-exporter:9100'] }]
  - job_name: cadvisor
    static_configs: [{ targets: ['cadvisor:8080'] }]
  - job_name: traefik
    static_configs: [{ targets: ['traefik:8080'] }]
  - job_name: blackbox
    metrics_path: /probe
    params: { module: [http_2xx] }
    static_configs:
      - targets:
        - https://forum.yeswas.pl
        - https://social.ovh
        - https://rss.social.ovh
        - https://pawelorzech.pl
        - https://dash.orzech.me
        - https://run.orzech.me
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
EOF

  cat > /opt/services/monitoring/prometheus/rules/alerts.yml <<'EOF'
groups:
- name: general.rules
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 2m
    labels: { severity: critical }
    annotations:
      summary: "Instance {{ $labels.instance }} down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} down >2m"
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100) > 80
    for: 5m
    labels: { severity: warning }
    annotations: { summary: "High CPU {{ $labels.instance }}" }
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes*100 > 90
    for: 5m
    labels: { severity: warning }
    annotations: { summary: "High memory {{ $labels.instance }}" }
  - alert: DiskSpaceLow
    expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}/node_filesystem_size_bytes) < 0.1
    for: 10m
    labels: { severity: warning }
    annotations: { summary: "Low disk {{ $labels.instance }}" }
  - alert: CertificateExpiration
    expr: probe_ssl_earliest_cert_expiry - time() < 604800
    for: 0m
    labels: { severity: warning }
    annotations: { summary: "Cert expires soon {{ $labels.instance }}" }
EOF

  # Blackbox config
  cat > /opt/services/monitoring/blackbox/blackbox.yml <<'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1","HTTP/2.0"]
      valid_status_codes: [200,301,302]
      method: GET
      follow_redirects: true
      tls_config: { insecure_skip_verify: false }
EOF

  # Alertmanager config with file-based password
  cat > /opt/services/monitoring/alertmanager/alertmanager.yml <<EOF
global:
  smtp_smarthost: '$ALERT_SMTP_HOST'
  smtp_from: '$ALERT_SMTP_FROM'
  smtp_auth_username: '$ALERT_SMTP_USER'
  smtp_auth_password_file: '/etc/alertmanager/secrets/smtp_pass'
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'
receivers:
- name: 'email'
  email_configs:
  - to: '$ADMIN_EMAIL'
    subject: 'Alert: {{ "{{" }} .GroupLabels.alertname {{ "}}" }}'
    send_resolved: true
EOF

  # Grafana provisioning
  cat > /opt/services/monitoring/grafana/provisioning/datasources/prometheus.yml <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF

  # Versions file
  cat > /opt/services/monitoring/versions.env <<EOF
PROMETHEUS_VER=$PROMETHEUS_VER
NODE_EXPORTER_VER=$NODE_EXPORTER_VER
CADVISOR_VER=$CADVISOR_VER
BLACKBOX_VER=$BLACKBOX_VER
GRAFANA_VER=$GRAFANA_VER
ALERTMANAGER_VER=$ALERTMANAGER_VER
EOF

  # Compose
  cat > /opt/services/monitoring/docker-compose.yml <<'EOF'
networks:
  monitoring:
  traefik_proxy:
    external: true
services:
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VER}
    container_name: prometheus
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=30d
      - --web.enable-lifecycle
      - --web.external-url=https://prometheus.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.prom.rule=Host(`prometheus.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.prom.entrypoints=websecure
      - traefik.http.routers.prom.tls.certresolver=le-dns
      - traefik.http.routers.prom.middlewares=security-headers@file

  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VER}
    container_name: node-exporter
    restart: unless-stopped
    networks: [monitoring]
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - --path.procfs=/host/proc
      - --path.rootfs=/rootfs
      - --path.sysfs=/host/sys
      - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)
    security_opt: [no-new-privileges:true]
    read_only: true
    cap_drop: [ALL]

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:${CADVISOR_VER}
    container_name: cadvisor
    restart: unless-stopped
    networks: [monitoring]
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    privileged: true
    devices: ["/dev/kmsg:/dev/kmsg"]

  blackbox-exporter:
    image: prom/blackbox-exporter:${BLACKBOX_VER}
    container_name: blackbox-exporter
    restart: unless-stopped
    networks: [monitoring]
    volumes:
      - ./blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml:ro
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]

  alertmanager:
    image: prom/alertmanager:${ALERTMANAGER_VER}
    container_name: alertmanager
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
      - ${ALERT_SMTP_PASS_PATH}:/etc/alertmanager/secrets/smtp_pass:ro
    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
      - --web.external-url=https://alertmanager.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    read_only: true
    tmpfs: ["/tmp:size=64m"]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:9093/-/healthy"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.alert.rule=Host(`alertmanager.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.alert.entrypoints=websecure
      - traefik.http.routers.alert.tls.certresolver=le-dns
      - traefik.http.routers.alert.middlewares=security-headers@file

  grafana:
    image: grafana/grafana:${GRAFANA_VER}
    container_name: grafana
    user: "472"
    restart: unless-stopped
    networks: [monitoring, traefik_proxy]
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_ROOT_URL: https://grafana.${PRIMARY_DOMAIN}
    security_opt: [no-new-privileges:true]
    cap_drop: [ALL]
    healthcheck:
      test: ["CMD","wget","-qO-","http://localhost:3000/api/health"]
      interval: 30s
      timeout: 3s
      retries: 5
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`grafana.${PRIMARY_DOMAIN}`)
      - traefik.http.routers.grafana.entrypoints=websecure
      - traefik.http.routers.grafana.tls.certresolver=le-dns
      - traefik.http.routers.grafana.middlewares=security-headers@file

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:
EOF

  # secure launch: 1) create temp file for smtp pass, 2) inject env via monitoring.env.sops
  (
    cd /opt/services/monitoring
    sops exec-file --no-fifo ./alertmanager/secrets/smtp_pass.sops \
      'ALERT_SMTP_PASS_PATH={} sops exec-file --no-fifo ./secrets/monitoring.env.sops \
        "docker compose --env-file ./versions.env --env-file {} up -d"'
  )
}

main(){
  ensure_root
  timedatectl set-timezone "$TIMEZONE"
  install_node_and_gemini
  install_base_tools
  bootstrap_sops
  create_admin_user
  harden_ssh
  configure_firewall
  system_baseline
  install_docker
  prepare_secrets
  deploy_traefik
  deploy_monitoring
  log "Base ready - secrets via sops, no plaintext .env, Grafana no fallback password, Alertmanager password via file."
}

main "$@"
```
