# /etc/nixos/configuration.nix
{ config, pkgs, lib, ... }:

let
  isX86 = pkgs.stdenv.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;

  optionalKdePkg = name:
    if builtins.hasAttr name pkgs.kdePackages then [ pkgs.kdePackages.${name} ]
    else if builtins.hasAttr name pkgs then [ pkgs.${name} ]
    else [];

  # 0. ICÔNES VECTORIELLES SVG (Bouton IA ✨, Catalogue IA ★, Hub Comptes & Clouds ☁️)
  customAiIcons = pkgs.runCommand "custom-ai-icons" {} ''
    mkdir -p $out/share/icons/hicolor/scalable/apps

    cat << 'EOF' > $out/share/icons/hicolor/scalable/apps/ai-assistant-spark.svg
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <defs>
        <linearGradient id="aiGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#2563EB"/>
          <stop offset="50%" stop-color="#7C3AED"/>
          <stop offset="100%" stop-color="#EC4899"/>
        </linearGradient>
      </defs>
      <rect width="56" height="56" x="4" y="4" rx="16" fill="url(#aiGrad)"/>
      <path d="M32 12 C34 24 40 30 52 32 C40 34 34 40 32 52 C30 40 24 34 12 32 C24 30 30 24 32 12 Z" fill="#FFFFFF"/>
      <path d="M48 12 C49 16 51 18 55 19 C51 20 49 22 48 26 C47 22 45 20 41 19 C45 18 47 16 48 12 Z" fill="#FDE047"/>
      <circle cx="18" cy="46" r="2.5" fill="#FDE047"/>
    </svg>
    EOF

    cat << 'EOF' > $out/share/icons/hicolor/scalable/apps/ai-catalog-selector.svg
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect width="56" height="56" x="4" y="4" rx="16" fill="#0F172A" stroke="#38BDF8" stroke-width="3"/>
      <path d="M32 15 L36 26 L48 26 L38 33 L42 45 L32 38 L22 45 L26 33 L16 26 L28 26 Z" fill="#FACC15"/>
    </svg>
    EOF

    cat << 'EOF' > $out/share/icons/hicolor/scalable/apps/rome-store-hub.svg
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect width="56" height="56" x="4" y="4" rx="16" fill="#0D9488"/>
      <rect width="16" height="16" x="14" y="14" rx="4" fill="#FFFFFF"/>
      <rect width="16" height="16" x="34" y="14" rx="4" fill="#99F6E4"/>
      <rect width="16" height="16" x="14" y="34" rx="4" fill="#99F6E4"/>
      <rect width="16" height="16" x="34" y="34" rx="4" fill="#FACC15"/>
    </svg>
    EOF

    cat << 'EOF' > $out/share/icons/hicolor/scalable/apps/oem-welcome-wizard.svg
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect width="56" height="56" x="4" y="4" rx="16" fill="#4F46E5"/>
      <circle cx="32" cy="32" r="18" fill="none" stroke="#E0E7FF" stroke-width="3"/>
      <polygon points="32,14 38,28 50,32 38,36 32,50 26,36 14,32 26,28" fill="#FDE047"/>
    </svg>
    EOF

    cat << 'EOF' > $out/share/icons/hicolor/scalable/apps/cloud-universal-hub.svg
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
      <rect width="56" height="56" x="4" y="4" rx="16" fill="#0284C7"/>
      <path d="M22 44 H44 C49.5 44 54 39.5 54 34 C54 29 50.2 24.8 45.3 24.1 C43.4 17.2 37.1 12 29.5 12 C20.4 12 13 19.4 13 28.5 C13 29.1 13 29.7 13.1 30.3 C9.6 31.8 7 35.3 7 39.5 C7 45 11.5 44 22 44 Z" fill="#FFFFFF"/>
    </svg>
    EOF
  '';

  # 1. WRAPPER CHROME EN RUST NATIF (Zéro fork Bash/hostname/readlink/kill)
  browserWrapper = pkgs.writers.writeRustBin "dynamic-browser" {} ''
    use std::fs;
    use std::os::unix::process::CommandExt;
    use std::path::PathBuf;
    use std::process::Command;

    fn is_pid_alive(pid: u32) -> bool {
        PathBuf::from(format!("/proc/{}", pid)).exists()
    }

    fn clean_singleton_lock(profile_dir: &PathBuf, current_host: &str) {
        let lock_path = profile_dir.join("SingletonLock");
        if let Ok(target) = fs::read_link(&lock_path) {
            let t_str = target.to_string_lossy();
            if let Some((host, pid_str)) = t_str.rsplit_once('-') {
                let pid: u32 = pid_str.parse().unwrap_or(0);
                if host != current_host || pid == 0 || !is_pid_alive(pid) {
                    let _ = fs::remove_file(profile_dir.join("SingletonLock"));
                    let _ = fs::remove_file(profile_dir.join("SingletonCookie"));
                    let _ = fs::remove_file(profile_dir.join("SingletonSocket"));
                }
            }
        }
    }

    fn main() {
        let current_host = fs::read_to_string("/proc/sys/kernel/hostname")
            .unwrap_or_default()
            .trim()
            .to_string();

        if let Ok(home) = std::env::var("HOME") {
            let h = PathBuf::from(home);
            clean_singleton_lock(&h.join(".config/google-chrome"), &current_host);
            clean_singleton_lock(&h.join(".local/share/ai-sidebar-profile"), &current_host);
        }

        let user_args: Vec<String> = std::env::args().skip(1).collect();
        for bin in ["google-chrome-stable", "chromium"] {
            let mut cmd = Command::new(bin);
            cmd.args([
                "--ozone-platform=x11",
                "--renderer-process-limit=8",
                "--AggressiveCacheDiscard",
            ]);
            cmd.args(&user_args);
            let _ = cmd.exec();
        }
    }
  '';

  # 2. SÉLECTEUR AUTOMATIQUE D'IA (100% Dynamique, État partagé en RAM /dev/shm)
  aiDynamicSelector = pkgs.writeShellScriptBin "ai-dynamic-selector" ''
    set -uo pipefail
    export PATH="${ lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.ollama pkgs.procps pkgs.inotify-tools ] }:$PATH"
    [ -z "''${HOME:-}" ] || [ ! -w "''${HOME:-/nonexistent}" ] && export HOME="/tmp"

    LOOPBACK="127.0.0.1"
    OLLAMA_URL="http://$LOOPBACK:${toString config.services.ollama.port}"
    SHM_STATE="/dev/shm/ai-optimal-model"

    until curl -sf "$OLLAMA_URL/api/tags" >/dev/null 2>&1; do
      inotifywait -q -t 1 -e create,open /run >/dev/null 2>&1 || true
    done

    ollama rm "1-IA-LA-PLUS-ADAPTEE:recommandee" 2>/dev/null || true

    MEM_TOTAL_BYTES=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)

    VRAM_BYTES=0
    for vram_file in /sys/class/drm/card*/device/mem_info_vram_total; do
      if [ -f "$vram_file" ]; then
        V=$(cat "$vram_file" 2>/dev/null || echo 0)
        [ "$V" -gt "$VRAM_BYTES" ] && VRAM_BYTES="$V"
      fi
    done

    if [ "$VRAM_BYTES" -gt 2147483648 ]; then
      MAX_MODEL_BYTES=$((MEM_TOTAL_BYTES * 35 / 100))
      MIN_MODEL_BYTES=$((MEM_TOTAL_BYTES * 12 / 100))
      echo "[AI-Dynamic] GPU dédié détecté ($((VRAM_BYTES / 1024 / 1024)) Mo VRAM)"
    else
      MAX_MODEL_BYTES=$((MEM_TOTAL_BYTES * 10 / 100))
      MIN_MODEL_BYTES=$((MEM_TOTAL_BYTES * 4 / 100))
      echo "[AI-Dynamic] Mode CPU/iGPU rapide activé (Enveloppe RAM : 4% -> 10%)"
    fi

    INSTALLED_LIST=$(curl -sf "$OLLAMA_URL/api/tags" | jq -r --argjson max "$MAX_MODEL_BYTES" '
      .models[]? | select(.size > $max or (.name | test("(?i)1-IA-LA-PLUS-ADAPTEE|Mistral-7B-Instruct-v0\\.3|MiMo|Ornith"))) | .name
    ' || true)
    for OLD_MOD in $INSTALLED_LIST; do
      ollama rm "$OLD_MOD" || true
    done

    SELECTED_MODEL=$(curl -sf "$OLLAMA_URL/api/tags" | jq -r --argjson max "$MAX_MODEL_BYTES" --argjson min "$MIN_MODEL_BYTES" '
      [.models[]? | select(.size <= $max and .size >= $min)] | sort_by(.size) | last | .name // empty
    ')

    if [ -z "$SELECTED_MODEL" ]; then
      until curl -sfI "https://huggingface.co" >/dev/null 2>&1; do
        inotifywait -q -t 1 -e modify,create /run/systemd/resolve >/dev/null 2>&1 || true
      done

      REPOS=$(curl -sf "https://huggingface.co/api/models?author=bartowski&filter=gguf&sort=downloads&direction=-1&limit=80" | jq -r '
        .[] | select(.id | test("(?i)(Qwen2\\.5-[0-9\\.]+B-Instruct|Llama-3\\.2-[0-9\\.]+B-Instruct)")) | select(.id | test("(?i)(Distill|R1|Vision|VL|1M)") | not) | .id
      ')

      BEST_SIZE=0
      for REPO in $REPOS; do
        CANDIDATE=$(curl -sf "https://huggingface.co/api/models/$REPO?blobs=true" | jq -r --argjson max "$MAX_MODEL_BYTES" --argjson min "$MIN_MODEL_BYTES" '
          [.siblings[]?
            | select(.rfilename | test("(?i)(Q4_K_M|Q4_K_S)\\.gguf$"))
            | select(.rfilename | test("(?i)-of-[0-9]+\\.gguf$|mmproj") | not)
            | select(.size != null and .size <= $max and .size >= $min)
          ] | sort_by(.size) | last | if . != null then "\(.size)|\(.rfilename)" else empty end
        ' || true)

        if [ -n "$CANDIDATE" ]; then
          FILE_SIZE=$(echo "$CANDIDATE" | cut -d'|' -f1)
          FILE_NAME=$(echo "$CANDIDATE" | cut -d'|' -f2)
          if [ "$FILE_SIZE" -gt "$BEST_SIZE" ]; then
            BEST_SIZE="$FILE_SIZE"
            QUANT_TAG=$(echo "$FILE_NAME" | grep -ioE '(Q4_K_M|Q4_K_S)' | head -n1 | tr '[:lower:]' '[:upper:]')
            SELECTED_MODEL="hf.co/$REPO:$QUANT_TAG"
            if [ "$BEST_SIZE" -ge $((MAX_MODEL_BYTES * 60 / 100)) ]; then
              break
            fi
          fi
        fi
      done

      if [ -n "$SELECTED_MODEL" ]; then
        ollama pull "$SELECTED_MODEL"
      fi
    fi

    if [ -n "$SELECTED_MODEL" ]; then
      rm -f "$SHM_STATE" 2>/dev/null || true
      echo "$SELECTED_MODEL" > "$SHM_STATE" 2>/dev/null || true
      chmod 0666 "$SHM_STATE" 2>/dev/null || true
      if [ "$HOME" != "/tmp" ] && [ -w "$HOME" ]; then
        mkdir -p "$HOME/.config"
        echo "$SELECTED_MODEL" > "$HOME/.config/ai-optimal-model" 2>/dev/null || true
      fi
      curl -sf "$OLLAMA_URL/api/generate" -d "{\"model\":\"$SELECTED_MODEL\",\"prompt\":\"\",\"keep_alive\":\"30m\"}" >/dev/null 2>&1 &
    fi
  '';

  # 3. CATALOGUE GRAPHIQUE DES MODÈLES IA
  aiModelChooserGui = pkgs.writeShellScriptBin "ai-model-selector" ''
    export PATH="${ lib.makeBinPath [ pkgs.kdePackages.kdialog pkgs.kdePackages.qttools pkgs.curl pkgs.jq pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.ollama ] }:$PATH"
    export LD_LIBRARY_PATH="${ lib.makeLibraryPath [ pkgs.pipewire ] }:''${LD_LIBRARY_PATH:-}"

    CHOICE=$(kdialog --title "Catalogue des Modèles IA" \
      --geometry 760x440 \
      --radiolist "Sélectionnez le modèle IA à télécharger et activer (Nom et Poids) :" \
      "hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF:Q4_K_M" "Llama-3.2-1B-Instruct (Q4_K_M — 808 Mo)" off \
      "hf.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF:Q4_K_M" "Qwen2.5-1.5B-Instruct (Q4_K_M — 986 Mo)" on \
      "hf.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF:Q4_K_M" "Qwen2.5-Coder-1.5B-Instruct (Q4_K_M — 986 Mo)" off \
      "hf.co/bartowski/Qwen2.5-3B-Instruct-GGUF:Q4_K_M" "Qwen2.5-3B-Instruct (Q4_K_M — 1,93 Go)" off \
      "hf.co/bartowski/Qwen2.5-Coder-3B-Instruct-GGUF:Q4_K_M" "Qwen2.5-Coder-3B-Instruct (Q4_K_M — 1,93 Go)" off \
      "hf.co/bartowski/Qwen2.5-7B-Instruct-GGUF:Q4_K_M" "Qwen2.5-7B-Instruct (Q4_K_M — 4,68 Go)" off 2>/dev/null || true)

    [ -z "$CHOICE" ] && exit 0

    DBUS_REF=$(kdialog --title "Téléchargement du modèle IA" --progressbar "Téléchargement de $CHOICE..." 100 2>/dev/null || true)
    DBUS_SERVICE=$(echo "$DBUS_REF" | awk '{print $1}')
    DBUS_PATH=$(echo "$DBUS_REF" | awk '{print $2}')

    if [ -n "$DBUS_SERVICE" ] && [ -n "$DBUS_PATH" ]; then
      qdbus "$DBUS_SERVICE" "$DBUS_PATH" Set "" value 40 >/dev/null 2>&1 || true
    fi

    ollama pull "$CHOICE"
    rm -f /dev/shm/ai-optimal-model 2>/dev/null || true
    echo "$CHOICE" > /dev/shm/ai-optimal-model 2>/dev/null || true
    chmod 0666 /dev/shm/ai-optimal-model 2>/dev/null || true
    mkdir -p "$HOME/.config"
    echo "$CHOICE" > "$HOME/.config/ai-optimal-model" 2>/dev/null || true

    if [ -n "$DBUS_SERVICE" ] && [ -n "$DBUS_PATH" ]; then
      qdbus "$DBUS_SERVICE" "$DBUS_PATH" Set "" value 100 >/dev/null 2>&1 || true
      qdbus "$DBUS_SERVICE" "$DBUS_PATH" close >/dev/null 2>&1 || true
    fi

    kdialog --title "Modèle installé" --msgbox "Le modèle $CHOICE est installé et prêt à l'emploi." 2>/dev/null || true
  '';

  aiModelChooserDesktop = pkgs.makeDesktopItem {
    name = "ai-model-selector";
    desktopName = "Catalogue des Modèles IA";
    comment = "Choisir et télécharger un modèle IA par nom et poids";
    exec = "${aiModelChooserGui}/bin/ai-model-selector";
    icon = "ai-catalog-selector";
    categories = [ "Utility" "System" ];
  };

  # 4. HUB UNIVERSEL DE CONNEXION DE COMPTES & CLOUDS
  cloudAccountsManager = pkgs.writeShellScriptBin "cloud-accounts-manager" ''
    export PATH="/run/wrappers/bin:${ lib.makeBinPath [ browserWrapper pkgs.xdg-utils pkgs.kdePackages.kdialog pkgs.kdePackages.dolphin pkgs.alacritty pkgs.rclone pkgs.util-linux pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.systemd pkgs.gh pkgs.thunderbird pkgs.kdePackages.systemsettings pkgs.inotify-tools ] }:$PATH"
    export LD_LIBRARY_PATH="${ lib.makeLibraryPath [ pkgs.pipewire ] }:''${LD_LIBRARY_PATH:-}"
    export BROWSER="${browserWrapper}/bin/dynamic-browser"

    PROVIDER=$(kdialog --title "Hub Universel des Comptes & Clouds" \
      --geometry 820x540 \
      --menu "Connectez n'importe quel compte Cloud, Mail ou Développement.\nLes stockages Cloud seront montés en temps réel dans ~/Clouds et ajoutés au volet gauche de Dolphin :" \
      "gdrive" "🔵 Google (Google Drive, Docs, Photos via OAuth2 Navigateur)" \
      "onedrive" "🟦 Microsoft (OneDrive Personnel, Office 365, SharePoint, Teams)" \
      "nextcloud" "🌐 Nextcloud / ownCloud / WebDAV (Serveur Cloud Privé ou Entreprise)" \
      "dropbox" "📦 Dropbox (Stockage Cloud & Synchronisation automatique)" \
      "mega" "🔴 MEGA (Stockage chiffré grande capacité)" \
      "protondrive" "🟣 Proton Drive (Stockage Cloud chiffré de bout en bout)" \
      "pcloud" "🟢 pCloud / Box / iCloud / S3 / SFTP (Assistant complet Rclone)" \
      "mail" "✉️ Messagerie, Agendas & Contacts (Gmail, Outlook, iCloud, Exchange via Thunderbird)" \
      "syncthing" "🔄 Syncthing (Synchronisation P2P continue multi-appareils : 127.0.0.1:8384)" \
      "github" "🐙 GitHub / GitLab (Authentification CLI & Git)" 2>/dev/null || true)

    [ -z "$PROVIDER" ] && exit 0

    mkdir -p "$HOME/Clouds" "$HOME/.config/rclone"

    PLACES_FILE="$HOME/.local/share/user-places.xbel"
    if [ -f "$PLACES_FILE" ] && ! grep -q "$HOME/Clouds" "$PLACES_FILE" 2>/dev/null; then
      sed -i "s|</xbel>|  <bookmark href=\"file://$HOME/Clouds\">\n    <title>Clouds Connectés</title>\n    <info>\n      <metadata owner=\"http://freedesktop.org\">\n        <bookmark:icon name=\"folder-cloud\"/>\n      </metadata>\n    </info>\n  </bookmark>\n</xbel>|" "$PLACES_FILE" || true
    fi

    mount_rclone_remote() {
      REMOTE_NAME="$1"
      REMOTE_TYPE="$2"
      NEEDS_OAUTH="$3"
      MOUNT_DIR="$HOME/Clouds/$REMOTE_NAME"
      mkdir -p "$MOUNT_DIR"

      if [ "$NEEDS_OAUTH" = "yes" ] && ! rclone config show "$REMOTE_NAME" 2>/dev/null | grep -qE "token|pass|url"; then
        rclone config delete "$REMOTE_NAME" >/dev/null 2>&1 || true

        alacritty --title "Connexion OAuth2 - $REMOTE_NAME" -e bash -c "
          export BROWSER='${browserWrapper}/bin/dynamic-browser'
          rclone config create '$REMOTE_NAME' '$REMOTE_TYPE' config_is_local true
        "

        if ! rclone config show "$REMOTE_NAME" 2>/dev/null | grep -qE "token|pass|url"; then
          kdialog --title "Connexion annulée ou incomplète" --error \
            "L'autorisation de $REMOTE_NAME n'a pas été finalisée dans le navigateur." 2>/dev/null || true
          exit 1
        fi
      fi

      mkdir -p "$HOME/.config/systemd/user"
      cat <<EOF > "$HOME/.config/systemd/user/rclone-mount-$REMOTE_NAME.service"
[Unit]
Description=Montage automatique Cloud $REMOTE_NAME dans ~/Clouds/$REMOTE_NAME
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment="PATH=/run/wrappers/bin:/run/current-system/sw/bin"
Environment="GOGC=50"
Environment="GOMEMLIMIT=256MiB"
ExecStartPre=-/run/wrappers/bin/fusermount3 -uz %h/Clouds/$REMOTE_NAME
ExecStartPre=${pkgs.coreutils}/bin/mkdir -p %h/Clouds/$REMOTE_NAME
ExecStart=${pkgs.rclone}/bin/.rclone-wrapped mount $REMOTE_NAME: %h/Clouds/$REMOTE_NAME --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-write-back 5s --buffer-size 32M --use-mmap --dir-cache-time 15m --transfers 16 --checkers 32 --volname $REMOTE_NAME
ExecStop=-/run/wrappers/bin/fusermount3 -uz %h/Clouds/$REMOTE_NAME
MemoryHigh=256M
MemoryMax=384M
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF
      systemctl --user daemon-reload
      systemctl --user restart "rclone-mount-$REMOTE_NAME.service" || true
      systemctl --user enable "rclone-mount-$REMOTE_NAME.service" || true

      MOUNT_OK=0
      for _ in $(seq 1 10); do
        if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
          MOUNT_OK=1
          break
        fi
        inotifywait -q -t 1 -e open,access,attrib "$MOUNT_DIR" >/dev/null 2>&1 || true
      done

      if [ "$MOUNT_OK" -eq 1 ]; then
        dolphin "$MOUNT_DIR" >/dev/null 2>&1 &
      fi
    }

    case "$PROVIDER" in
      gdrive) mount_rclone_remote "GoogleDrive" "drive" "yes" ;;
      onedrive) mount_rclone_remote "OneDrive" "onedrive" "yes" ;;
      dropbox) mount_rclone_remote "Dropbox" "dropbox" "yes" ;;
      mega)
        EMAIL=$(kdialog --title "Connexion MEGA" --inputbox "Adresse e-mail de votre compte MEGA :" 2>/dev/null || true)
        PASS=$(kdialog --title "Connexion MEGA" --password "Mot de passe MEGA :" 2>/dev/null || true)
        if [ -n "$EMAIL" ] && [ -n "$PASS" ]; then
          rclone config delete "MEGA" >/dev/null 2>&1 || true
          rclone config create "MEGA" mega user "$EMAIL" pass "$PASS" --obscure
          mount_rclone_remote "MEGA" "mega" "no"
        fi
        ;;
      protondrive)
        alacritty --title "Configuration ProtonDrive" -e rclone config
        mount_rclone_remote "ProtonDrive" "protondrive" "no"
        ;;
      nextcloud)
        URL=$(kdialog --title "Connexion Nextcloud / WebDAV" --inputbox "URL WebDAV :" 2>/dev/null || true)
        USER_NC=$(kdialog --title "Connexion Nextcloud" --inputbox "Identifiant :" 2>/dev/null || true)
        PASS_NC=$(kdialog --title "Connexion Nextcloud" --password "Mot de passe / Jeton :" 2>/dev/null || true)
        if [ -n "$URL" ] && [ -n "$USER_NC" ] && [ -n "$PASS_NC" ]; then
          rclone config delete "Nextcloud" >/dev/null 2>&1 || true
          rclone config create "Nextcloud" webdav url "$URL" vendor "nextcloud" user "$USER_NC" pass "$PASS_NC" --obscure
          mount_rclone_remote "Nextcloud" "webdav" "no"
        fi
        ;;
      pcloud) alacritty --title "Configuration Rclone Universelle" -e rclone config & ;;
      mail) thunderbird & ;;
      syncthing) ${browserWrapper}/bin/dynamic-browser --app="http://127.0.0.1:8384" & ;;
      github) alacritty --title "Connexion GitHub / GitLab" -e gh auth login & ;;
    esac
  '';

  cloudAccountsDesktop = pkgs.makeDesktopItem {
    name = "cloud-accounts-manager";
    desktopName = "Comptes & Clouds (Google, OneDrive, Tous Comptes)";
    comment = "Connecter Google Drive, OneDrive, Dropbox, Nextcloud, Mails et monter automatiquement les disques Cloud";
    exec = "${cloudAccountsManager}/bin/cloud-accounts-manager";
    icon = "cloud-universal-hub";
    categories = [ "Network" "System" "Settings" ];
  };

  # 5. GUIDE DE PREMIÈRE INSTALLATION STYLE ANDROID
  oemFirstBootWizard = pkgs.writeShellScriptBin "oem-first-boot-wizard" ''
    export PATH="${ lib.makeBinPath [ pkgs.kdePackages.kdialog pkgs.networkmanager pkgs.coreutils pkgs.gawk pkgs.util-linux pkgs.shadow pkgs.sudo ] }:$PATH"
    export LD_LIBRARY_PATH="${ lib.makeLibraryPath [ pkgs.pipewire ] }:''${LD_LIBRARY_PATH:-}"

    MEM_GB=$(awk '/MemTotal/ {printf "%d", $2 / 1024 / 1024}' /proc/meminfo)
    CPU_NAME=$(LC_ALL=C lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')

    kdialog --title "Bienvenue sur votre nouveau PC" --yesno \
      "Bienvenue dans l'assistant de première configuration !\n\nMatériel détecté automatiquement :\n• Processeur : $CPU_NAME\n• Mémoire vive : ''${MEM_GB} Go RAM (+ Compression ZRAM 150%)\n\nVoulez-vous commencer ?" 2>/dev/null || exit 0

    if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
      ${pkgs.networkmanagerapplet}/bin/nm-connection-editor 2>/dev/null || true
    fi

    ${aiModelChooserGui}/bin/ai-model-selector

    if kdialog --title "Étape 3/3 : Comptes Google, OneDrive, Mails & Clouds" --yesno \
      "Souhaitez-vous connecter vos comptes maintenant ?" 2>/dev/null ; then
      ${cloudAccountsManager}/bin/cloud-accounts-manager
    fi

    mkdir -p "$HOME/.config"
    touch "$HOME/.config/oem-wizard-completed"
  '';

  oemWizardDesktop = pkgs.makeDesktopItem {
    name = "oem-first-boot-wizard";
    desktopName = "Guide de Première Installation";
    comment = "Assistant d'accueil, de configuration et de calibrage IA";
    exec = "${oemFirstBootWizard}/bin/oem-first-boot-wizard";
    icon = "oem-welcome-wizard";
    categories = [ "System" "Settings" ];
  };

  # 6. OUTIL DE REMISE D'USINE POUR LA REVENTE ("Factory Reset")
  factoryResetScript = pkgs.writeShellScriptBin "factory-reset-pc" ''
    export PATH="${ lib.makeBinPath [ pkgs.kdePackages.kdialog pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.shadow pkgs.systemd pkgs.polkit ] }:$PATH"
    export LD_LIBRARY_PATH="${ lib.makeLibraryPath [ pkgs.pipewire ] }:''${LD_LIBRARY_PATH:-}"

    if [ "$(id -u)" -ne 0 ]; then
      if ! kdialog --title "Remise à zéro d'usine (Mode Revente)" --warningyesno \
        "⚠️ ATTENTION : REMISE D'USINE COMPLÈTE ⚠️\n\nVoulez-vous vraiment remettre ce PC à l'état d'usine ?" 2>/dev/null; then
        exit 0
      fi
      exec pkexec "$0" --confirm-wipe
    fi

    if [ "''${1:-}" = "--confirm-wipe" ]; then
      rm -rf /etc/NetworkManager/system-connections/*
      systemctl stop open-webui.service || true
      rm -rf /var/lib/open-webui/data/*

      for U in $(awk -F: '$3 >= 1000 && $3 < 29000 && $1 !~ /^nixbld/ && $6 ~ /^\/home\// {print $1}' /etc/passwd); do
        pkill -9 -u "$U" || true
        userdel -r -f "$U" 2>/dev/null || true
        rm -rf "/home/$U"
      done

      useradd -m -G wheel,disk,networkmanager,systemd-journal,video,podman,lp,scanner -s /run/current-system/sw/bin/bash utilisateur
      echo "utilisateur:bienvenu" | chpasswd
      rm -rf /etc/nixos/.git /etc/nixos/gitops-remote.url
      chown -R utilisateur:users /etc/nixos

      systemctl reboot
    fi
  '';

  factoryResetDesktop = pkgs.makeDesktopItem {
    name = "factory-reset-pc";
    desktopName = "Remettre le PC d'usine (Mode Vente)";
    comment = "Efface les données personnelles et active le Guide de Première Installation pour un nouveau client";
    exec = "${factoryResetScript}/bin/factory-reset-pc";
    icon = "system-reboot";
    categories = [ "System" ];
  };

  # 7. PROVISIONNEMENT AUTOMATIQUE DU BUREAU WINDOWS 11 POUR TOUT UTILISATEUR
  plasmaWin11Setup = pkgs.writeShellScriptBin "plasma-win11-setup" ''
    export PATH="${ lib.makeBinPath [ pkgs.coreutils pkgs.kdePackages.kconfig pkgs.kdePackages.qttools pkgs.kdePackages.plasma-workspace ] }:$PATH"
    export LD_LIBRARY_PATH="${ lib.makeLibraryPath [ pkgs.pipewire ] }:''${LD_LIBRARY_PATH:-}"

    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "org.kde.breezedark.desktop"
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "Fluent-dark"
    kwriteconfig6 --file kdeglobals --group KDE --key SingleClick false
    kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false
    kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false

    if [ ! -f "$HOME/.config/win11-panel-configured-v4" ]; then
      rm -f "$HOME/.cache/icon-cache.kcache"
      qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        var allPanels = panels();
        for (var i = 0; i < allPanels.length; i++) {
          allPanels[i].remove();
        }
        var panel = new Panel("org.kde.panel");
        panel.location = "bottom";
        panel.height = 46;
        panel.floating = true;
        panel.addWidget("org.kde.plasma.panelspacer");
        var kickoff = panel.addWidget("org.kde.plasma.kickoff");
        kickoff.currentConfigGroup = ["General"];
        kickoff.writeConfig("icon", "start-here-kde-symbolic");
        var tasks = panel.addWidget("org.kde.plasma.icontasks");
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("launchers", [
          "applications:google-chrome.desktop",
          "applications:org.kde.dolphin.desktop",
          "applications:onlyoffice-desktopeditors.desktop",
          "applications:rome-universal-launcher.desktop",
          "applications:ai-sidebar.desktop",
          "applications:ai-model-selector.desktop",
          "applications:cloud-accounts-manager.desktop",
          "applications:oem-first-boot-wizard.desktop",
          "applications:systemsettings.desktop",
          "applications:Alacritty.desktop"
        ]);
        panel.addWidget("org.kde.plasma.panelspacer");
        panel.addWidget("org.kde.plasma.systemtray");
        panel.addWidget("org.kde.plasma.digitalclock");
        panel.addWidget("org.kde.plasma.showdesktop");
      ' 2>/dev/null && touch "$HOME/.config/win11-panel-configured-v4" || true
    fi

    for DDIR in "$HOME/Bureau" "$HOME/Desktop"; do
      if [ -d "$DDIR" ]; then
        cp -f /run/current-system/sw/share/applications/rome-universal-launcher.desktop "$DDIR/" 2>/dev/null || true
        cp -f /run/current-system/sw/share/applications/oem-first-boot-wizard.desktop "$DDIR/" 2>/dev/null || true
        chmod +x "$DDIR/rome-universal-launcher.desktop" "$DDIR/oem-first-boot-wizard.desktop" 2>/dev/null || true
      fi
    done

    if [ ! -f "$HOME/.config/oem-wizard-completed" ]; then
      ${oemFirstBootWizard}/bin/oem-first-boot-wizard &
    fi
  '';

  # 8. BANDEAU LATÉRAL IA EN RUST NATIF (Lecture directe /sys/class/drm + Socket TCP sans curl/xrandr)
  aiSidebarScript = pkgs.writers.writeRustBin "ai-sidebar" {} ''
    use std::fs;
    use std::net::{SocketAddr, TcpStream};
    use std::os::unix::process::CommandExt;
    use std::path::PathBuf;
    use std::process::Command;
    use std::thread;
    use std::time::Duration;

    fn detect_screen_geometry() -> (u32, u32) {
        if let Ok(entries) = fs::read_dir("/sys/class/drm") {
            for entry in entries.flatten() {
                let path = entry.path();
                if let Ok(status) = fs::read_to_string(path.join("status")) {
                    if status.trim() == "connected" {
                        if let Ok(modes) = fs::read_to_string(path.join("modes")) {
                            if let Some(first) = modes.lines().next() {
                                if let Some((w_s, h_s)) = first.trim().split_once('x') {
                                    let w: u32 = w_s.parse().unwrap_or(1920);
                                    let h: u32 = h_s.parse().unwrap_or(1080);
                                    if w > 0 && h > 0 {
                                        return (w, h);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        (1920, 1080)
    }

    fn main() {
        let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
        let profile = PathBuf::from(&home).join(".local/share/ai-sidebar-profile");
        let _ = fs::create_dir_all(&profile);
        let _ = fs::remove_file(profile.join("SingletonLock"));
        let _ = fs::remove_file(profile.join("SingletonCookie"));
        let _ = fs::remove_file(profile.join("SingletonSocket"));

        let addr = SocketAddr::from(([127, 0, 0, 1], ${toString config.services.open-webui.port}));
        for _ in 0..30 {
            if TcpStream::connect_timeout(&addr, Duration::from_millis(250)).is_ok() {
                break;
            }
            thread::sleep(Duration::from_millis(250));
        }

        let (screen_w, screen_h) = detect_screen_geometry();
        let sidebar_w = screen_w * 28 / 100;
        let pos_x = screen_w.saturating_sub(sidebar_w);

        let _ = Command::new("${browserWrapper}/bin/dynamic-browser")
            .args([
                &format!("--user-data-dir={}", profile.to_string_lossy()),
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-sync",
                &format!("--app=http://127.0.0.1:${toString config.services.open-webui.port}"),
                &format!("--window-size={},{}", sidebar_w, screen_h),
                &format!("--window-position={},0", pos_x),
                "--class=AISidebar",
            ])
            .exec();
    }
  '';

  aiSidebarDesktop = pkgs.makeDesktopItem {
    name = "ai-sidebar";
    desktopName = "Bandeau IA ✨";
    comment = "Ouvrir le Bandeau Latéral d'Intelligence Artificielle (Super + A)";
    exec = "${aiSidebarScript}/bin/ai-sidebar";
    icon = "ai-assistant-spark";
    categories = [ "Utility" "Science" ];
  };

  # 9. AGENT IA BAS NIVEAU EN RUST NATIF (writeRustBin : Syscalls /proc & /sys + Socket TCP direct)
  aiDiagScript = pkgs.writers.writeRustBin "ai-diag" {} ''
    use std::fs;
    use std::io::{self, BufRead, BufReader, Write};
    use std::net::TcpStream;
    use std::process::Command;
    use std::thread;

    fn read_trimmed(path: &str) -> String {
        fs::read_to_string(path).unwrap_or_default().trim().to_string()
    }

    fn probe_cpu() -> String {
        let cpuinfo = fs::read_to_string("/proc/cpuinfo").unwrap_or_default();
        let mut model = String::from("Generic CPU");
        let mut cores = 0;
        for line in cpuinfo.lines() {
            if line.starts_with("model name") || line.starts_with("Model") {
                if let Some(v) = line.split(':').nth(1) {
                    model = v.trim().to_string();
                }
            }
            if line.starts_with("processor") {
                cores += 1;
            }
        }
        let max_khz: u64 = read_trimmed("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
            .parse()
            .unwrap_or(0);
        format!("Arch:{} | Coeurs:{} | Modele:{} | Max:{}MHz", std::env::consts::ARCH, cores, model, max_khz / 1000)
    }

    fn probe_ram_zram() -> String {
        let meminfo = fs::read_to_string("/proc/meminfo").unwrap_or_default();
        let (mut total_kb, mut avail_kb) = (0u64, 0u64);
        for line in meminfo.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                match parts[0] {
                    "MemTotal:" => total_kb = parts[1].parse().unwrap_or(0),
                    "MemAvailable:" => avail_kb = parts[1].parse().unwrap_or(0),
                    _ => {}
                }
            }
        }
        let used_kb = total_kb.saturating_sub(avail_kb);
        let zram_stat = read_trimmed("/sys/block/zram0/mm_stat");
        let zparts: Vec<u64> = zram_stat.split_whitespace().filter_map(|s| s.parse().ok()).collect();
        let (orig_mb, compr_mb) = if zparts.len() >= 2 {
            (zparts[0] as f64 / 1048576.0, zparts[1] as f64 / 1048576.0)
        } else {
            (0.0, 0.0)
        };
        format!(
            "RAM_Totale:{:.1}Gi Utilisee:{:.1}Gi Dispo:{:.1}Gi | ZRAM_utilisee:{:.1}Mo_RAM(donnees_compressees:{:.1}Mo)",
            total_kb as f64 / 1048576.0,
            used_kb as f64 / 1048576.0,
            avail_kb as f64 / 1048576.0,
            compr_mb,
            orig_mb
        )
    }

    fn probe_resilience_psi() -> String {
        let mut zombies = 0;
        if let Ok(entries) = fs::read_dir("/proc") {
            for entry in entries.flatten() {
                let fname = entry.file_name();
                if fname.to_string_lossy().chars().all(|c| c.is_ascii_digit()) {
                    let stat_path = entry.path().join("stat");
                    if let Ok(stat) = fs::read_to_string(stat_path) {
                        if let Some(rparen) = stat.rfind(')') {
                            if stat[rparen + 1..].trim_start().starts_with('Z') {
                                zombies += 1;
                            }
                        }
                    }
                }
            }
        }
        let z_label = if zombies == 0 { String::from("0_fuite(sain)") } else { format!("{} zombies", zombies) };
        let ksm_run = read_trimmed("/sys/kernel/mm/ksm/run");
        let ksm_pages: u64 = read_trimmed("/sys/kernel/mm/ksm/pages_sharing").parse().unwrap_or(0);
        let psi_extract = |p: &str| -> String {
            fs::read_to_string(p)
                .unwrap_or_default()
                .lines()
                .next()
                .and_then(|l| l.split_whitespace().nth(1))
                .unwrap_or("avg10=0.00")
                .to_string()
        };
        format!(
            "Etat_memoire:{} | KSM_actif:{}({:.1}Mo) | PSI CPU({}) RAM({}) IO({})",
            z_label,
            ksm_run,
            (ksm_pages * 4096) as f64 / 1048576.0,
            psi_extract("/proc/pressure/cpu"),
            psi_extract("/proc/pressure/memory"),
            psi_extract("/proc/pressure/io")
        )
    }

    fn probe_thermals() -> String {
        let mut out = Vec::new();
        if let Ok(hwmons) = fs::read_dir("/sys/class/hwmon") {
            for hw in hwmons.flatten() {
                let path = hw.path();
                let name = read_trimmed(&path.join("name").to_string_lossy());
                for idx in 1..=4 {
                    let tpath = path.join(format!("temp{}_input", idx));
                    if let Ok(val) = read_trimmed(&tpath.to_string_lossy()).parse::<i64>() {
                        if val > 0 {
                            out.push(format!("{}:{}°C", name, val / 1000));
                            break;
                        }
                    }
                }
                let fpath = path.join("fan1_input");
                if let Ok(fan) = read_trimmed(&fpath.to_string_lossy()).parse::<u64>() {
                    out.push(format!("ventilateur:{}RPM", fan));
                }
            }
        }
        out.join(" | ")
    }

    fn probe_clouds() -> String {
        let mounts = fs::read_to_string("/proc/mounts").unwrap_or_default();
        let mut clouds = Vec::new();
        for line in mounts.lines() {
            let p: Vec<&str> = line.split_whitespace().collect();
            if p.len() >= 3 && (p[2].contains("rclone") || p[2] == "cifs" || p[2].starts_with("nfs")) {
                clouds.push(format!("{}({}->{})", p[0], p[2], p[1]));
            }
        }
        if clouds.is_empty() { String::from("Aucun") } else { clouds.join(" ") }
    }

    fn run_cmd(bin: &str, args: &[&str]) -> String {
        Command::new(bin)
            .args(args)
            .env("LC_ALL", "C")
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_default()
    }

    fn unescape_json_str(s: &str, key: &str) -> Option<String> {
        let pat = format!("\"{}\":\"", key);
        let start = s.find(&pat)? + pat.len();
        let mut out = String::new();
        let mut chars = s[start..].chars();
        while let Some(c) = chars.next() {
            if c == '"' {
                return Some(out);
            } else if c == '\\' {
                match chars.next()? {
                    '"' => out.push('"'),
                    '\\' => out.push('\\'),
                    '/' => out.push('/'),
                    'n' => out.push('\n'),
                    'r' => {}
                    't' => out.push('\t'),
                    'u' => {
                        let hex: String = chars.by_ref().take(4).collect();
                        if let Ok(code) = u32::from_str_radix(&hex, 16) {
                            if let Some(ch) = char::from_u32(code) {
                                out.push(ch);
                            }
                        }
                    }
                    other => out.push(other),
                }
            } else {
                out.push(c);
            }
        }
        None
    }

    fn extract_json_u64(s: &str, key: &str) -> u64 {
        let pat = format!("\"{}\":", key);
        if let Some(pos) = s.find(&pat) {
            let rest = &s[pos + pat.len()..];
            let digits: String = rest
                .chars()
                .skip_while(|c| c.is_whitespace())
                .take_while(|c| c.is_ascii_digit())
                .collect();
            digits.parse().unwrap_or(0)
        } else {
            0
        }
    }

    fn main() {
        let topo = fs::read_to_string("/run/os-topology/env").unwrap_or_default();
        let get_var = |key: &str, def: &str| -> String {
            topo.lines()
                .find_map(|l| l.strip_prefix(&format!("{}=", key)))
                .unwrap_or(def)
                .to_string()
        };

        let ncpus = thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
        let def_cpus = format!("0-{}", ncpus.saturating_sub(1));
        let def_threads = ncpus.to_string();

        let p_cpus = get_var("P_CPUS", &def_cpus);
        let e_cpus = get_var("E_CPUS", &def_cpus);
        let threads: u32 = get_var("OPTIMAL_THREADS", &def_threads).parse().unwrap_or(ncpus as u32);
        let batch: u32 = get_var("OPTIMAL_BATCH", "256").parse().unwrap_or(256);
        let ctx: u32 = get_var("OPTIMAL_CTX", "2048").parse().unwrap_or(2048);
        let gpu: u32 = get_var("USE_GPU", "0").parse().unwrap_or(0);

        let mut model = read_trimmed("/dev/shm/ai-optimal-model");
        if model.is_empty() {
            if let Ok(home) = std::env::var("HOME") {
                model = read_trimmed(&format!("{}/.config/ai-optimal-model", home));
            }
        }
        if model.is_empty() {
            model = String::from("hf.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF:Q4_K_M");
        }

        println!("=== AUDIT NATIF RUST BAS NIVEAU (MODÈLE : {} | P-CORES : {} | E-CORES : {}) ===", model, p_cpus, e_cpus);

        let (cpu, ram_zram, res_psi, therm, cloud, disks, smart, sec, jrn) = thread::scope(|s| {
            let h_cpu = s.spawn(probe_cpu);
            let h_ram = s.spawn(probe_ram_zram);
            let h_res = s.spawn(probe_resilience_psi);
            let h_thm = s.spawn(probe_thermals);
            let h_cld = s.spawn(probe_clouds);
            let h_dsk = s.spawn(|| {
                let raw = run_cmd("${pkgs.util-linux}/bin/lsblk", &["-rn", "-o", "NAME,FSTYPE,SIZE,FSUSE%,MOUNTPOINT"]);
                raw.lines()
                    .filter_map(|l| {
                        let p: Vec<&str> = l.split_whitespace().collect();
                        if p.len() >= 5 && p[0] != "zram0" {
                            Some(format!("{}({},{},util:{},mnt:{})", p[0], p[1], p[2], p[3], p[4]))
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>()
                    .join(" ")
            });
            let h_smt = s.spawn(|| {
                let mut out = Vec::new();
                if let Ok(entries) = fs::read_dir("/sys/class/block") {
                    for entry in entries.flatten() {
                        let dev = entry.file_name().to_string_lossy().to_string();
                        if dev.starts_with("loop") || dev.starts_with("ram") || dev.starts_with("zram") || dev.starts_with("dm-") || dev.starts_with("sr") || dev.starts_with("fd") {
                            continue;
                        }
                        let bpath = entry.path();
                        if bpath.join("device").exists() && !bpath.join("partition").exists() {
                            let dev_path = format!("/dev/{}", dev);
                            if dev.starts_with("nvme") {
                                let raw = run_cmd("/run/wrappers/bin/sudo", &["-n", "${pkgs.nvme-cli}/bin/nvme", "smart-log", &dev_path]);
                                for l in raw.lines() {
                                    if l.contains("critical_warning") || l.contains("temperature") || l.contains("percentage_used") || l.contains("media_errors") {
                                        let clean = l.split('(').next().unwrap_or(l);
                                        let compact = clean.split_whitespace().collect::<Vec<_>>().join("");
                                        out.push(format!("[{}]{}", dev, compact));
                                    }
                                }
                            } else {
                                let raw = run_cmd("/run/wrappers/bin/sudo", &["-n", "${pkgs.smartmontools}/bin/smartctl", "-H", "-A", &dev_path]);
                                for l in raw.lines() {
                                    if l.contains("overall-health") || l.contains("Temperature_Celsius") || l.contains("Reallocated_Sector") {
                                        out.push(format!("[{}]{}", dev, l.trim()));
                                    }
                                }
                            }
                        }
                    }
                }
                out.join(" ")
            });
            let h_sec = s.spawn(|| {
                let svcs = ["apparmor", "auditd", "fail2ban", "clamav-daemon", "prometheus-node-exporter", "chronyd", "smartd", "ananicy-cpp"];
                let states = run_cmd("${pkgs.systemd}/bin/systemctl", &[&["is-active"], &svcs[..]].concat());
                svcs.iter()
                    .zip(states.lines())
                    .map(|(k, v)| format!("{}:{}", k.trim_end_matches("-daemon").trim_end_matches("-cpp"), v))
                    .collect::<Vec<_>>()
                    .join(" ")
            });
            let h_jrn = s.spawn(|| {
                let raw = run_cmd("${pkgs.systemd}/bin/journalctl", &["-p", "err..emerg", "-n", "10", "--no-pager", "-q"]);
                let filtered: Vec<&str> = raw
                    .lines()
                    .filter(|l| !l.contains("Ignoring duplicate name"))
                    .take(2)
                    .collect();
                if filtered.is_empty() { String::from("0_erreur_critique") } else { filtered.join(" | ") }
            });

            (
                h_cpu.join().unwrap_or_default(),
                h_ram.join().unwrap_or_default(),
                h_res.join().unwrap_or_default(),
                h_thm.join().unwrap_or_default(),
                h_cld.join().unwrap_or_default(),
                h_dsk.join().unwrap_or_default(),
                h_smt.join().unwrap_or_default(),
                h_sec.join().unwrap_or_default(),
                h_jrn.join().unwrap_or_default(),
            )
        });

        println!("[Étage 1 — Télémétrie Native Rust (/proc & /sys directs en RAM)]");
        println!(" 1. CPU        : {}", cpu);
        println!(" 2. Disques    : {}", disks);
        println!(" 3. SMART      : {}", smart);
        println!(" 4. RAM & ZRAM : {}", ram_zram);
        println!(" 5. Résilience : {}", res_psi);
        println!(" 6. Sécurité   : {}", sec);
        println!(" 7. Cloud FUSE : {}", cloud);
        println!(" 8. Thermique  : {}", therm);
        println!(" 9. Journaux   : {}", jrn);
        println!("--------------------------------------------------------------------------------");
        println!("[Étage 2 — Diagnostic Analytique IA généré par les P-Cores ({})]", p_cpus);

        let prompt = format!(
            "Releves NixOS : CPU={} Partitions={} SMART={} Memoire={} Resilience={} Securite={} Cloud={} Thermique={} Journaux={}. Redige uniquement 4 points courts numerotes de 1 a 4 (une seule phrase directe par point, sans sous-puces) : 1. Sante CPU et thermique : 2. Efficience RAM, ZRAM et absence de fuite : 3. Stockage NVMe, Cloud et securite : 4. Action recommandee :",
            cpu, disks, smart, ram_zram, res_psi, sec, cloud, therm, jrn
        );

        let payload = format!(
            "{{\"model\":\"{}\",\"prompt\":{:?},\"stream\":true,\"keep_alive\":\"30m\",\"options\":{{\"num_ctx\":{},\"num_batch\":{},\"num_thread\":{},\"num_gpu\":{},\"num_predict\":320,\"temperature\":0.1,\"repeat_penalty\":1.2}}}}",
            model, prompt, ctx, batch, threads, gpu
        );

        if let Ok(mut stream) = TcpStream::connect("127.0.0.1:${toString config.services.ollama.port}") {
            let req = format!(
                "POST /api/generate HTTP/1.0\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                payload.len(),
                payload
            );
            let _ = stream.write_all(req.as_bytes());
            let reader = BufReader::new(stream);
            for line in reader.lines().flatten() {
                let trimmed = line.trim();
                if !trimmed.starts_with('{') {
                    continue;
                }
                if let Some(err) = unescape_json_str(trimmed, "error") {
                    eprintln!("\n[Erreur Ollama] {}", err);
                    break;
                }
                if let Some(tok) = unescape_json_str(trimmed, "response") {
                    print!("{}", tok);
                    let _ = io::stdout().flush();
                }
                if trimmed.contains("\"done\":true") {
                    let p_ns = extract_json_u64(trimmed, "prompt_eval_duration") as f64 / 1e9;
                    let e_ns = extract_json_u64(trimmed, "eval_duration") as f64 / 1e9;
                    let e_cnt = extract_json_u64(trimmed, "eval_count") as f64;
                    let tps = if e_ns > 0.0 { e_cnt / e_ns } else { 0.0 };
                    println!(
                        "\n--------------------------------------------------------------------------------\n[Télémétrie Native Rust TCP] Lecture prompt (Prefill) : {:.2}s | Génération : {:.2}s ({:.1} tokens/s)",
                        p_ns, e_ns, tps
                    );
                    break;
                }
            }
        }
    }
  '';
in
{
  # =========================================================================
  # 0. COMPRESSION ROM (SSD), AUTO-OPTIMISATION NIX & LOGS DE COMPILATION
  # =========================================================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = "auto";
    cores = 0;
    auto-optimise-store = true;
    keep-build-log = true;
  };

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # =========================================================================
  # 1. SÉCURITÉ, INTÉGRITÉ BAS NIVEAU, FIM, EBPF, MAC, TPM & AUDIT EXHAUSTIF
  # =========================================================================
  security.apparmor = {
    enable = true;
    killUnconfinedConfinables = true;
    packages = with pkgs; [ apparmor-profiles ];
  };

  security.auditd.enable = true;
  security.audit = {
    enable = true;
    backlogLimit = 65536;
    rules = [
      "-a exit,always -F arch=b64 -S execve -k exec_trace"
      "-a exit,always -F arch=b64 -S init_module,finit_module,delete_module -k kernel_modules"
      "-a exit,always -F arch=b64 -S mount,umount2 -k mounts"
      "-a exit,always -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change"
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/sudoers -p wa -k privilege_escalation"
      "-w /etc/nixos -p wa -k nixos_config"
      "-w /etc/systemd -p wa -k systemd_tamper"
    ];
  };

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  services.clamav = {
    daemon.enable = true;
    daemon.settings = {
      OnAccessIncludePath = [ "/home" "/tmp" "/var/tmp" ];
      OnAccessPrevention = false;
      OnAccessExtraScanning = true;
      OnAccessExcludeUname = "clamav";
      ConcurrentDatabaseReload = false;
    };
    updater.enable = true;
    scanner.enable = true;
  };

  systemd.services.clamav-freshclam = {
    after = [ "network-online.target" "systemd-resolved.service" ];
    wants = [ "network-online.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = lib.mkForce "on-failure";
      RestartSec = lib.mkForce 30;
    };
  };

  systemd.services.clamav-daemon = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      MemoryHigh = "900M";
      MemoryMax = "1400M";
      TasksMax = 128;
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 5;
    };
  };

  systemd.services.clamonacc-fanotify = {
    description = "Analyse antivirale à l'accès en temps réel via hooks noyau fanotify (Clamonacc)";
    wantedBy = [ "multi-user.target" ];
    after = [ "clamav-daemon.service" ];
    requires = [ "clamav-daemon.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      Nice = 19;
      CPUWeight = 20;
      IOWeight = 20;
      MemoryHigh = "256M";
      MemoryMax = "512M";
      TasksMax = 64;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -S /run/clamav/clamd.ctl ]; do ${pkgs.inotify-tools}/bin/inotifywait -q -t 1 -e create /run /run/clamav >/dev/null 2>&1 || true; done'";
      ExecStart = "${pkgs.clamav}/bin/clamonacc --foreground";
      Restart = "always";
      RestartSec = 5;
    };
  };

  networking.nftables.enable = true;
  networking.firewall.enable = true;
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
      overalljails = true;
    };
  };

  services.osquery.enable = true;
  systemd.services.osqueryd = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      MemoryHigh = "256M";
      MemoryMax = "512M";
      TasksMax = 64;
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 5;
    };
  };

  systemd.services.fim-and-rootkit-auditor = {
    description = "Vérification FIM cryptographique (AIDE) et audit de sécurité noyau (Lynis)";
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      CPUWeight = 10;
      CPUQuota = "25%";
      IOSchedulingClass = "idle";
      IOWeight = 10;
      MemoryHigh = "512M";
      MemoryMax = "768M";
    };
    script = ''
      mkdir -p /var/lib/aide
      if [ ! -f /var/lib/aide/aide.db ]; then
        cat << 'EOF' > /var/lib/aide/aide.conf
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
/boot sha256+perms+inode
/etc sha256+perms+inode
EOF
        ${pkgs.aide}/bin/aide --config=/var/lib/aide/aide.conf --init >/dev/null 2>&1 || true
        mv -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
      else
        ${pkgs.aide}/bin/aide --config=/var/lib/aide/aide.conf --check || true
      fi
      ${pkgs.lynis}/bin/lynis audit system --quick --quiet || true
    '';
  };

  systemd.timers.fim-and-rootkit-auditor = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # =========================================================================
  # 2. INDEXATION PLEIN TEXTE, OCR AUTOMATISÉ, MÉTADONNÉES & RECHERCHE
  # =========================================================================
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "hourly";
  };

  systemd.user.services.universal-indexer-ocr = {
    description = "Indexation plein texte (Recoll), OCR automatique (Tesseract) et extraction EXIF/Médias";
    path = with pkgs; [ recoll tesseract ocrmypdf exiftool mediainfo poppler coreutils findutils ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      MemoryHigh = "512M";
      MemoryMax = "768M";
    };
    script = ''
      mkdir -p "$HOME/.recoll"
      if [ ! -f "$HOME/.recoll/recoll.conf" ]; then
        cat <<EOF > "$HOME/.recoll/recoll.conf"
topdirs = ~
skippedNames = .cache .local .nix-profile .cargo node_modules Clouds
ocrprogs = tesseract
tesseractlang = fra+eng
EOF
      fi
      recollindex -m -x -w 5 >/dev/null 2>&1 || true
    '';
  };

  systemd.user.timers.universal-indexer-ocr = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "30m";
    };
  };

  # =========================================================================
  # 3. STOCKAGE, SNAPSHOTS, SCRUBBING, DÉDUPLICATION, SMART & AUTO-RÉPARATION FS
  # =========================================================================
  boot.initrd.checkJournalingFS = true;

  services.fstrim = {
    enable = true;
    interval = "daily";
  };

  services.btrfs.autoScrub = {
    enable = lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems);
    interval = "weekly";
  };

  services.systembus-notify.enable = lib.mkForce true;
  services.smartd = {
    notifications.systembus-notify.enable = true;
    enable = true;
    autodetect = true;
    defaults.autodetected = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,55";
  };

  systemd.services.storage-snapshot-and-dedup = {
    description = "Snapshots automatisés (CoW/Hardlink) avec rétention et déduplication physique des blocs";
    path = with pkgs; [ btrfs-progs rsync jdupes duperemove e2fsprogs coreutils util-linux gawk ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      CPUWeight = 10;
      CPUQuota = "25%";
      IOSchedulingClass = "idle";
      IOWeight = 10;
      MemoryHigh = "512M";
      MemoryMax = "1G";
    };
    script = ''
      mkdir -p /.snapshots
      STAMP=$(date +%Y%m%d-%H%M%S)
      ROOT_FS=$(df -T / | awk 'NR==2 {print $2}')

      if [ "$ROOT_FS" = "btrfs" ]; then
        btrfs subvolume snapshot -r / "/.snapshots/root-$STAMP" || true
        duperemove -drh /home /var/lib 2>/dev/null || true
      else
        LAST_SNAP=$(ls -1d /.snapshots/home-* 2>/dev/null | tail -n 1 || true)
        if [ -n "$LAST_SNAP" ]; then
          rsync -a --delete --exclude='/Clouds' --link-dest="$LAST_SNAP" /home/ "/.snapshots/home-$STAMP/" || true
        else
          rsync -a --exclude='/Clouds' /home/ "/.snapshots/home-$STAMP/" || true
        fi
        jdupes -r -L /home 2>/dev/null || true
      fi

      ls -1dt /.snapshots/* 2>/dev/null | tail -n +8 | xargs -r rm -rf || true
    '';
  };

  systemd.timers.storage-snapshot-and-dedup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  services.lvm.enable = true;

  # =========================================================================
  # 4. ARCHITECTURE PYRAMIDALE, ANTI-FUITE MÉMOIRE & AUTO-RÉPARATION (100% RUST ELF)
  # =========================================================================
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.timeout = 1;

  boot.kernelPackages = if isX86 then pkgs.linuxPackages_zen else pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tcp_bbr" "fuse" "bcache" "dm-cache" ] ++ lib.optionals isX86 [ "msr" "coretemp" "k10temp" "asus-nb-wmi" "iTCO_wdt" "sp5100_tco" ];

  boot.kernelParams = [
    "pcie_aspm=off"
    "nvme_core.default_ps_max_latency_us=0"
    "transparent_hugepage=madvise"
    "psi=1"
    "acpi_osi=Linux"
    "log_buf_len=64M"
    "loglevel=7"
    "printk.devkmsg=on"
    "printk.time=1"
    "audit=1"
    "audit_backlog_limit=65536"
    "panic=10"
    "oops=panic"
    "softlockup_panic=1"
  ] ++ lib.optionals isX86 [
    "intel_pstate=active"
    "amd_pstate=active"
  ];

  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "50%";
  };

  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root 6h"
    "d /var/tmp 1777 root root 24h"
    "d /run/os-topology 0755 root root -"
    "d /var/lib/ollama/.cache/mesa_shader_cache 0755 root root -"
    "w+ /sys/kernel/mm/lru_gen/enabled - - - - y"
    "w+ /sys/kernel/mm/lru_gen/min_ttl_ms - - - - 1000"
    "w+ /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
    "w+ /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
    "w+ /sys/kernel/mm/ksm/pages_to_scan - - - - 2000"
    "w+ /sys/kernel/mm/ksm/sleep_millisecs - - - - 10"
    "w+ /sys/kernel/mm/ksm/run - - - - 1"
  ];

  environment.etc."systemd/system.conf.d/99-perpetual-resilience.conf".text = ''
    [Manager]
    RuntimeWatchdogSec=30s
    RebootWatchdogSec=2m
    KExecWatchdogSec=1m
    DefaultTimeoutStartSec=45s
    DefaultTimeoutStopSec=15s
    DefaultRestartSec=2s
    DefaultStartLimitIntervalSec=60s
    DefaultStartLimitBurst=10
    DefaultMemoryAccounting=yes
    DefaultIOAccounting=yes
    DefaultCPUAccounting=yes
    DefaultTasksAccounting=yes
    DefaultTasksMax=4096
    DefaultLimitNOFILE=1048576
  '';

  environment.etc."systemd/user.conf.d/99-perpetual-resilience.conf".text = ''
    [Manager]
    DefaultTimeoutStartSec=30s
    DefaultTimeoutStopSec=10s
    DefaultRestartSec=2s
    DefaultStartLimitIntervalSec=60s
    DefaultStartLimitBurst=10
    DefaultLimitNOFILE=524288
  '';

  environment.variables = {
    GLIBC_TUNABLES = "glibc.malloc.trim_threshold=65536:glibc.malloc.arena_max=2:glibc.malloc.mmap_threshold=65536";
    MALLOC_TRIM_THRESHOLD_ = "65536";
    MALLOC_MMAP_THRESHOLD_ = "65536";
    MALLOC_ARENA_MAX = "2";
    GOGC = "50";
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 150;
    priority = 100;
  };

  hardware.ksm.enable = true;

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
  services.irqbalance.enable = true;

  systemd.services.predictive-binary-preloader = {
    description = "Préchargement prédictif en RAM des bibliothèques et binaires fréquemment utilisés (vmtouch)";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 15;
    };
    script = ''
      ${pkgs.vmtouch}/bin/vmtouch -t -q /run/current-system/sw/bin/bash /run/current-system/sw/bin/ollama /run/current-system/sw/bin/kwin_wayland 2>/dev/null || true
    '';
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.vfs_cache_pressure" = 50;
    "vm.compaction_proactiveness" = 20;
    "vm.zone_reclaim_mode" = 0;
    "vm.max_map_count" = 2147483642;
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 536870912;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.oom_kill_allocating_task" = 1;
    "kernel.sched_autogroup_enabled" = 1;
    "kernel.sched_migration_cost_ns" = 5000000;
    "kernel.panic" = 10;
    "kernel.panic_on_oops" = 1;
    "kernel.softlockup_panic" = 1;
    "kernel.hung_task_timeout_secs" = 120;
    "kernel.hung_task_panic" = 0;
    "kernel.printk" = "7 4 1 7";
    "kernel.printk_devkmsg" = "on";
    "kernel.printk_ratelimit" = 0;
    "kernel.printk_ratelimit_burst" = 0;
    "kernel.dmesg_restrict" = 0;
    "fs.aio-max-nr" = 2097152;
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 8192;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_keepalive_time" = 60;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;
    "net.ipv4.tcp_retries2" = 8;
    "net.ipv4.tcp_fin_timeout" = 15;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.core.netdev_max_backlog" = 16384;
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
  };

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none", ATTR{queue/nr_requests}="2048", ATTR{queue/read_ahead_kb}="4096", ATTR{queue/add_random}="0", ATTR{queue/rq_affinity}="2", ATTR{queue/nomerges}="0"
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]|mmcblk[0-9]|vd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline", ATTR{queue/nr_requests}="1024", ATTR{queue/read_ahead_kb}="2048", ATTR{queue/add_random}="0", ATTR{queue/rq_affinity}="2"
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq", ATTR{queue/nr_requests}="512", ATTR{queue/read_ahead_kb}="4096"
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="eth*|en*|wl*", RUN+="${pkgs.ethtool}/bin/ethtool -K $name gro on gso on tso on"
    ACTION=="add|change", SUBSYSTEM=="power_supply", ATTR{type}=="Battery", TEST=="charge_control_end_threshold", ATTR{charge_control_end_threshold}="80"
    SUBSYSTEM=="usb", ATTR{idVendor}=="04e8|18d1|0bb4|12d1|22b8|2717|05c6|0e8d|17ef", MODE="0666", GROUP="wheel", TAG+="uaccess"
  '';

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkIf isX86 true;
  hardware.cpu.amd.updateMicrocode = lib.mkIf isX86 true;

  hardware.graphics = {
    enable = true;
    enable32Bit = isX86;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      ocl-icd
    ] ++ lib.optionals isX86 [
      intel-media-driver
      intel-compute-runtime
      vpl-gpu-rt
      libva-vdpau-driver
    ];
  };

  # 4.1 DÉMON UNIVERSEL DE DÉTECTION TOPOLOGIQUE (/run/os-topology) EN RUST NATIF (writeRustBin)
  systemd.services.hardware-max-overdrive = {
    description = "Détection Topologique Universelle (/run/os-topology) & Ordonnancement Asymétrique P-Cores/E-Cores en Rust Natif";
    wantedBy = [ "multi-user.target" ];
    before = [ "ollama.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writers.writeRustBin "hardware-max-overdrive" {} ''
        use std::collections::BTreeSet;
        use std::fs;
        use std::path::Path;
        use std::process::Command;
        use std::thread;

        fn read_u64(path: &str, default: u64) -> u64 {
            fs::read_to_string(path)
                .ok()
                .and_then(|s| s.trim().trim_end_matches('K').parse::<u64>().ok())
                .unwrap_or(default)
        }

        fn join_usize(list: &[usize]) -> String {
            list.iter().map(|n| n.to_string()).collect::<Vec<_>>().join(",")
        }

        fn main() {
            let _ = fs::create_dir_all("/run/os-topology");
            let _ = fs::create_dir_all("/var/lib/ollama/.cache/mesa_shader_cache");

            let mut vram_bytes: u64 = 0;
            if let Ok(entries) = fs::read_dir("/sys/class/drm") {
                for entry in entries.flatten() {
                    let name = entry.file_name().to_string_lossy().into_owned();
                    if name.starts_with("card") && name[4..].chars().all(|c| c.is_ascii_digit()) && !name[4..].is_empty() {
                        let cpath = entry.path();
                        if let Ok(max_f) = fs::read_to_string(cpath.join("gt_max_freq_mhz")) {
                            let _ = fs::write(cpath.join("gt_boost_freq_mhz"), max_f.as_bytes());
                        }
                        let dpm = cpath.join("device/power_dpm_force_performance_level");
                        if dpm.exists() {
                            let _ = fs::write(dpm, b"high\n");
                        }
                        let vram = read_u64(&cpath.join("device/mem_info_vram_total").to_string_lossy(), 0);
                        if vram > vram_bytes {
                            vram_bytes = vram;
                        }
                    }
                }
            }

            let mut cpus: Vec<(usize, u64, u64)> = Vec::new();
            let mut max_score: u64 = 0;

            if let Ok(entries) = fs::read_dir("/sys/devices/system/cpu") {
                for entry in entries.flatten() {
                    let name = entry.file_name().to_string_lossy().into_owned();
                    if let Some(id_str) = name.strip_prefix("cpu") {
                        if !id_str.is_empty() && id_str.chars().all(|c| c.is_ascii_digit()) {
                            if let Ok(cpu_id) = id_str.parse::<usize>() {
                                let cpath = entry.path();
                                let freq = read_u64(&cpath.join("cpufreq/cpuinfo_max_freq").to_string_lossy(), 1_000_000);
                                let cap = read_u64(&cpath.join("cpu_capacity").to_string_lossy(), 1024);
                                let core_id = read_u64(&cpath.join("topology/core_id").to_string_lossy(), cpu_id as u64);
                                let score = (freq / 1000) * cap;
                                if score > max_score {
                                    max_score = score;
                                }
                                cpus.push((cpu_id, score, core_id));
                            }
                        }
                    }
                }
            }

            cpus.sort_by_key(|c| c.0);
            let total_cpus = cpus.len().max(1);
            let threshold = max_score * 85 / 100;

            let mut p_vec: Vec<usize> = Vec::new();
            let mut e_vec: Vec<usize> = Vec::new();
            let mut seen_cores: BTreeSet<u64> = BTreeSet::new();
            let mut phys_vec: Vec<usize> = Vec::new();

            for &(cpu_id, score, core_id) in &cpus {
                if score >= threshold {
                    p_vec.push(cpu_id);
                } else {
                    e_vec.push(cpu_id);
                }
                if seen_cores.insert(core_id) {
                    phys_vec.push(cpu_id);
                }
            }

            if phys_vec.is_empty() {
                phys_vec = (0..total_cpus).collect();
            }

            if e_vec.is_empty() && total_cpus > 1 {
                let half = total_cpus / 2;
                p_vec = (0..half).collect();
                e_vec = (half..total_cpus).collect();
            } else if p_vec.is_empty() {
                p_vec = phys_vec.clone();
            }

            let phys_count = phys_vec.len().max(1);
            let optimal_threads = p_vec.len().max(1);

            let p_list = join_usize(&p_vec);
            let e_list = join_usize(&e_vec);
            let all_phys_cpus = join_usize(&phys_vec);

            let l2_kb = read_u64("/sys/devices/system/cpu/cpu0/cache/index2/size", 1024);
            let optimal_batch: u64 = if l2_kb >= 2048 { 512 } else { 256 };

            let meminfo = fs::read_to_string("/proc/meminfo").unwrap_or_default();
            let mut mem_kb: u64 = 8_388_608;
            for line in meminfo.lines() {
                if line.starts_with("MemTotal:") {
                    if let Some(val) = line.split_whitespace().nth(1) {
                        mem_kb = val.parse().unwrap_or(8_388_608);
                    }
                    break;
                }
            }
            let mem_mb = mem_kb / 1024;
            let mem_gb = mem_mb / 1024;
            let ollama_gomemlimit_mib = mem_mb * 60 / 100;

            let has_nvidia = Path::new("/dev/nvidiactl").exists();
            let (optimal_ctx, kv_type, use_vulkan, flash_attn, use_gpu) = if has_nvidia {
                (4096u64, "q8_0", "0", "1", 99u64)
            } else if vram_bytes > 2_147_483_648 {
                (4096u64, "q8_0", "1", "1", 99u64)
            } else {
                (2048u64, "f16", "0", "0", 0u64)
            };

            let _ = fs::write("/run/pyramid-pcores.count", format!("{}\n", optimal_threads));
            let _ = fs::write("/run/pyramid-pcpus.list", format!("{}\n", p_list));
            let _ = fs::write("/run/pyramid-ecpus.list", format!("{}\n", e_list));
            let _ = fs::write("/run/pyramid-use-gpu.flag", format!("{}\n", use_gpu));

            let topo_env = format!(
                "ARCH={}\nTOTAL_CPUS={}\nPHYS_COUNT={}\nALL_PHYS_CPUS={}\nP_CPUS={}\nE_CPUS={}\nOPTIMAL_THREADS={}\nL2_CACHE_KB={}\nOPTIMAL_BATCH={}\nOPTIMAL_CTX={}\nMEM_GB={}\nVRAM_BYTES={}\nUSE_GPU={}\nOLLAMA_GOMEMLIMIT_MIB={}\n",
                std::env::consts::ARCH,
                total_cpus,
                phys_count,
                all_phys_cpus,
                p_list,
                e_list,
                optimal_threads,
                l2_kb,
                optimal_batch,
                optimal_ctx,
                mem_gb,
                vram_bytes,
                use_gpu,
                ollama_gomemlimit_mib
            );
            let _ = fs::write("/run/os-topology/env", topo_env);

            let ollama_env = format!(
                "OLLAMA_CONTEXT_LENGTH={}\nOLLAMA_KV_CACHE_TYPE={}\nOLLAMA_NUM_THREADS={}\nOLLAMA_VULKAN={}\nOLLAMA_FLASH_ATTENTION={}\nGOGC=50\nGOMEMLIMIT={}MiB\n",
                optimal_ctx, kv_type, optimal_threads, use_vulkan, flash_attn, ollama_gomemlimit_mib
            );
            let _ = fs::write("/run/ollama-dynamic.env", ollama_env);

            let mut wq_mask: u128 = 0;
            for &c in &e_vec {
                if c < 128 {
                    wq_mask |= 1u128 << c;
                }
            }
            if wq_mask > 0 {
                let hex_mask = format!("{:x}\n", wq_mask);
                if let Ok(wqs) = fs::read_dir("/sys/devices/virtual/workqueue") {
                    for wq in wqs.flatten() {
                        let cpumask_path = wq.path().join("cpumask");
                        if cpumask_path.exists() {
                            let _ = fs::write(cpumask_path, hex_mask.as_bytes());
                        }
                    }
                }
            }

            let bg_units = [
                "open-webui.service",
                "clamav-daemon.service",
                "clamonacc-fanotify.service",
                "osqueryd.service",
                "fail2ban.service",
                "prometheus-node-exporter.service",
                "fim-and-rootkit-auditor.service",
                "storage-snapshot-and-dedup.service",
                "nix-daemon.service",
                "rustdesk.service",
                "os-gitops-reconciler.service",
                "dns-threat-sinkhole.service",
                "update-locatedb.service",
            ];

            thread::scope(|s| {
                let p_arg = format!("AllowedCPUs={}", p_list);
                s.spawn(move || {
                    let _ = Command::new("${pkgs.systemd}/bin/systemctl")
                        .args(["set-property", "--runtime", "ollama.service", &p_arg, "CPUWeight=1000", "IOWeight=1000"])
                        .status();
                });

                for unit in bg_units {
                    let e_arg = format!("AllowedCPUs={}", e_list);
                    s.spawn(move || {
                        let _ = Command::new("${pkgs.systemd}/bin/systemctl")
                            .args(["set-property", "--runtime", unit, &e_arg])
                            .status();
                    });
                }
            });
        }
      ''}/bin/hardware-max-overdrive";
    };
  };

  # 4.2 PURGE PROACTIVE DES FUITES MÉMOIRE, ZOMBIES & RECLAMATION CGROUPS V2 (writeRustBin)
  systemd.services.memory-leak-reaper = {
    description = "Éradication native en Rust des fuites mémoire, processus zombies et pages cgroups v2 inactives";
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.writers.writeRustBin "memory-leak-reaper" {} ''
        use std::fs;
        use std::process::Command;

        fn main() {
            if let Ok(entries) = fs::read_dir("/proc") {
                for entry in entries.flatten() {
                    if entry.file_name().to_string_lossy().chars().all(|c| c.is_ascii_digit()) {
                        if let Ok(stat) = fs::read_to_string(entry.path().join("stat")) {
                            if let Some(rparen) = stat.rfind(')') {
                                let fields: Vec<&str> = stat[rparen + 1..].split_whitespace().collect();
                                if fields.len() >= 2 && fields[0] == "Z" {
                                    if let Ok(ppid) = fields[1].parse::<u32>() {
                                        if ppid > 1 {
                                            let _ = Command::new("${pkgs.util-linux}/bin/kill")
                                                .args(["-s", "SIGCHLD", &ppid.to_string()])
                                                .status();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            for unit in ["open-webui.service", "clamav-daemon.service", "osqueryd.service", "prometheus-node-exporter.service"] {
                let reclaim_path = format!("/sys/fs/cgroup/system.slice/{}/memory.reclaim", unit);
                let _ = fs::write(&reclaim_path, b"32M\n");
            }

            let meminfo = fs::read_to_string("/proc/meminfo").unwrap_or_default();
            let (mut total, mut avail) = (0u64, 0u64);
            for line in meminfo.lines() {
                let p: Vec<&str> = line.split_whitespace().collect();
                if p.len() >= 2 {
                    match p[0] {
                        "MemTotal:" => total = p[1].parse().unwrap_or(0),
                        "MemAvailable:" => avail = p[1].parse().unwrap_or(0),
                        _ => {}
                    }
                }
            }
            if total > 0 && (avail * 100 / total) < 15 {
                let _ = fs::write("/proc/sys/vm/drop_caches", b"2\n");
                let _ = fs::write("/proc/sys/vm/compact_memory", b"1\n");
            }
        }
      ''}/bin/memory-leak-reaper";
    };
  };

  systemd.timers.memory-leak-reaper = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
    };
  };

  # 4.3 DÉMON D'AUTO-RÉPARATION CONTINUE (writeRustBin : Sonde TCP directe + Syscalls FUSE ENOTCONN)
  systemd.services.system-self-healer = {
    description = "Auto-réparation native en Rust des unités systemd, sockets TCP IA, DNS et montages FUSE Cloud";
    serviceConfig = {
      Type = "oneshot";
      Nice = 10;
      ExecStart = "${pkgs.writers.writeRustBin "system-self-healer" {} ''
        use std::fs;
        use std::io::{Read, Write};
        use std::net::{SocketAddr, TcpStream};
        use std::process::Command;
        use std::thread;
        use std::time::Duration;

        fn is_unit_active(unit: &str) -> bool {
            Command::new("${pkgs.systemd}/bin/systemctl")
                .args(["is-active", "--quiet", unit])
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
        }

        fn restart_unit(unit: &str) {
            let _ = Command::new("${pkgs.systemd}/bin/systemctl")
                .args(["reset-failed", unit])
                .status();
            let _ = Command::new("${pkgs.systemd}/bin/systemctl")
                .args(["restart", unit])
                .status();
        }

        fn probe_ollama_tcp() -> bool {
            let addr = SocketAddr::from(([127, 0, 0, 1], ${toString config.services.ollama.port}));
            if let Ok(mut stream) = TcpStream::connect_timeout(&addr, Duration::from_secs(5)) {
                let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));
                let _ = stream.set_write_timeout(Some(Duration::from_secs(5)));
                if stream.write_all(b"GET /api/tags HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n").is_ok() {
                    let mut buf = [0u8; 64];
                    if let Ok(n) = stream.read(&mut buf) {
                        let resp = String::from_utf8_lossy(&buf[..n]);
                        return resp.starts_with("HTTP/1.");
                    }
                }
            }
            false
        }

        fn main() {
            thread::scope(|s| {
                s.spawn(|| {
                    if let Ok(out) = Command::new("${pkgs.systemd}/bin/systemctl")
                        .args(["list-units", "--state=failed", "--no-legend", "--plain"])
                        .output()
                    {
                        let stdout = String::from_utf8_lossy(&out.stdout);
                        for line in stdout.lines() {
                            if let Some(unit) = line.split_whitespace().next() {
                                if unit.starts_with("nixos-rebuild")
                                    || unit.starts_with("fim-and-rootkit")
                                    || unit.starts_with("storage-snapshot")
                                    || unit.starts_with("os-gitops-reconciler")
                                {
                                    continue;
                                }
                                restart_unit(unit);
                            }
                        }
                    }
                });

                s.spawn(|| {
                    if is_unit_active("ollama.service") && !probe_ollama_tcp() {
                        restart_unit("ollama.service");
                    }
                });

                s.spawn(|| {
                    if !is_unit_active("systemd-resolved.service") {
                        restart_unit("systemd-resolved.service");
                    }
                });

                s.spawn(|| {
                    if let Ok(homes) = fs::read_dir("/home") {
                        for home in homes.flatten() {
                            let clouds_dir = home.path().join("Clouds");
                            if let Ok(mounts) = fs::read_dir(&clouds_dir) {
                                for mnt in mounts.flatten() {
                                    let mpath = mnt.path();
                                    if let Err(err) = fs::read_dir(&mpath) {
                        let code = err.raw_os_error().unwrap_or(0);
                                        if code == 107 || code == 5 {
                                            let mstr = mpath.to_string_lossy();
                                            let status = Command::new("/run/wrappers/bin/fusermount3")
                                                .args(["-uz", &mstr])
                                                .status();
                                            if status.map(|st| !st.success()).unwrap_or(true) {
                                                let _ = Command::new("${pkgs.util-linux}/bin/umount")
                                                    .args(["-l", &mstr])
                                                    .status();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                });
            });
        }
      ''}/bin/system-self-healer";
    };
  };

  systemd.timers.system-self-healer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "1m";
    };
  };

  services.thermald.enable = isX86;
  services.power-profiles-daemon.enable = false;

  # 4.4 CALIBRAGE TLP UNIQUE (Autorise les C-States profonds sur coeurs inactifs pour maximiser le Turbo Boost P-Cores)
  services.tlp = {
    enable = true;
    settings = {
      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 1;
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 100;
      PCIE_ASPM_ON_AC = "performance";
      PCIE_ASPM_ON_BAT = "default";
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      USB_AUTOSUSPEND = 0;
    };
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
    IdleAction = "ignore";
  };

  systemd.oomd.enable = true;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 4;
    freeSwapThreshold = 10;
    enableNotifications = true;
    extraArgs = [
      "--avoid" "'^(systemd|plasmashell|kwin_wayland|sddm|sshd)$'"
      "--prefer" "'^(chrome|wine|wineserver|python3)$'"
    ];
  };

  # =========================================================================
  # 5. RÉSEAU, SINKHOLE DNS ACTIF, NTP HAUTE PRÉCISION & DÉCOUVERTE
  # =========================================================================
  networking.hostName = lib.mkDefault "universal";
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
    wifi.powersave = false;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS = "opportunistic";
      DNSSEC = "allow-downgrade";
      Cache = "yes";
      DNSStubListener = "yes";
      FallbackDNS = [
        "9.9.9.9#dns.quad9.net"
        "149.112.112.112#dns.quad9.net"
        "1.1.1.2#security.cloudflare-dns.com"
      ];
    };
  };

  systemd.services.dns-threat-sinkhole = {
    description = "Mise à jour active du filtrage DNS proactif dans /etc/hosts (Anti-Télémétrie, Anti-Pub, Anti-C2)";
    after = [ "network-online.target" "systemd-resolved.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
    script = ''
      if ${pkgs.curl}/bin/curl -sfL "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" -o /var/lib/hosts-blocklist.tmp; then
        {
          echo "127.0.0.1 localhost"
          echo "::1 localhost"
          echo "127.0.0.2 ${config.networking.hostName}"
          grep -E '^0\.0\.0\.0 ' /var/lib/hosts-blocklist.tmp | grep -v '0.0.0.0 0.0.0.0' || true
        } > /var/lib/hosts-blocklist
        ln -sf /var/lib/hosts-blocklist /etc/hosts
        rm -f /var/lib/hosts-blocklist.tmp
        ${pkgs.systemd}/bin/resolvectl flush-caches || true
      fi
    '';
  };

  systemd.timers.dns-threat-sinkhole = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  services.timesyncd.enable = false;
  services.chrony = {
    enable = true;
    enableNTS = true;
    servers = [ "time.cloudflare.com" "nts.netnod.se" "ptbtime1.ptb.de" ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
    openFirewall = true;
  };
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # =========================================================================
  # 6. OBSERVABILITÉ, MÉTRIQUES HAUTE FRÉQUENCE (GO) & JOURNALISATION ZSTD
  # =========================================================================
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [ "systemd" "processes" ];
  };

  systemd.services.prometheus-node-exporter = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Environment = [ "GOGC=50" "GOMEMLIMIT=128MiB" ];
      MemoryHigh = "96M";
      MemoryMax = "160M";
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce 2;
    };
  };

  services.sysstat.enable = true;
  services.vnstat.enable = true;

  systemd.coredump = {
    enable = true;
    settings.Coredump = {
      Storage = "external";
      Compress = true;
      MaxUse = "1G";
    };
  };

  services.journald.settings.Journal = {
    Storage = "persistent";
    Compress = "yes";
    Seal = "yes";
    SplitMode = "uid";
    SystemMaxUse = "4G";
    SystemKeepFree = "2G";
    SystemMaxFileSize = "128M";
    RuntimeMaxUse = "512M";
    MaxLevelStore = "debug";
    MaxLevelSyslog = "debug";
    MaxLevelKMsg = "debug";
    MaxLevelConsole = "info";
    ForwardToKMsg = "no";
    RateLimitIntervalSec = "0";
    RateLimitBurst = "0";
    SyncIntervalSec = "5m";
  };

  # =========================================================================
  # 7. RÉSILIENCE, SYNCHRONISATION BIDIRECTIONNELLE (GO) & ALIMENTATION
  # =========================================================================
  services.upower = {
    enable = true;
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "PowerOff";
  };

  systemd.user.services.syncthing-universal = {
    description = "Synchronisation continue et bidirectionnelle de fichiers (Syncthing Go)";
    wantedBy = [ "default.target" ];
    after = [ "network.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Environment = [ "GOGC=50" "GOMEMLIMIT=256MiB" ];
      ExecStart = "${pkgs.syncthing}/bin/syncthing serve --no-browser --no-restart --gui-address=127.0.0.1:8384";
      MemoryHigh = "256M";
      MemoryMax = "384M";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # =========================================================================
  # 8. IA EN ACCÈS ROOT LECTURE SEULE INTÉGRAL (ANTI-FUITE GOMEMLIMIT + AUTO-GUÉRISON)
  # =========================================================================
  programs.fuse.userAllowOther = true;
  boot.binfmt.emulatedSystems = if isX86 then [ "aarch64-linux" ] else [ "x86_64-linux" ];

  boot.binfmt.registrations.windows = lib.mkIf isX86 {
    recognitionType = "magic";
    magicOrExtension = "MZ";
    interpreter = "${pkgs.wineWow64Packages.staging}/bin/wine";
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  services.flatpak.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.printing.enable = true;
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    environmentVariables = {
      HOME = "/var/lib/ollama";
      XDG_CACHE_HOME = "/var/lib/ollama/.cache";
      MESA_SHADER_CACHE_DIR = "/var/lib/ollama/.cache/mesa_shader_cache";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_DEBUG = "1";
    };
  };

  systemd.services.ollama = {
    requires = [ "hardware-max-overdrive.service" ];
    after = [ "hardware-max-overdrive.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      EnvironmentFile = "-/run/ollama-dynamic.env";
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      ProtectSystem = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      ReadOnlyPaths = lib.mkForce [ "/" ];
      ReadWritePaths = lib.mkForce [ "/var/lib/ollama" "/tmp" "/run" "/dev/shm" ];
      DevicePolicy = lib.mkForce "auto";
      DeviceAllow = lib.mkForce [
        "block-* r"
        "char-drm rwm"
        "char-mem r"
        "char-pts rwm"
        "char-tty rwm"
        "char-usb_device r"
        "/dev/dri/renderD128 rwm"
        "/dev/dri/card0 rwm"
        "/dev/dri/card1 rwm"
        "/dev/kfd rwm"
        "/dev/null rwm"
        "/dev/zero rwm"
        "/dev/full rwm"
        "/dev/random r"
        "/dev/urandom r"
        "/dev/tty rwm"
        "/dev/ptmx rwm"
      ];
      MemoryHigh = "65%";
      MemoryMax = "75%";
      TasksMax = 512;
      CPUWeight = 1000;
      IOWeight = 1000;
      Nice = -10;
      Restart = "always";
      RestartSec = 2;
    };
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
      WEBUI_AUTH = "False";
      ENABLE_PERSISTENT_CONFIG = "False";
      PYTHONMALLOC = "malloc";
      MALLOC_TRIM_THRESHOLD_ = "65536";
      DEFAULT_MODEL_METADATA = "{\"params\":{\"function_calling\":\"default\"},\"capabilities\":{\"builtin_tools\":true,\"web_search\":true,\"code_interpreter\":true}}";
      ENABLE_RAG_WEB_SEARCH = "True";
      ENABLE_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "duckduckgo";
      WEB_SEARCH_ENGINE = "duckduckgo";
      RAG_WEB_SEARCH_RESULT_COUNT = "6";
      RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
      ENABLE_RAG_LOCAL_WEB_FETCH = "True";
      ENABLE_SEARCH_QUERY_GENERATION = "True";
      ENABLE_CODE_INTERPRETER = "True";
      ENABLE_AUTOCOMPLETE_GENERATION = "False";
      ENABLE_TAGS_GENERATION = "False";
      ENABLE_TITLE_GENERATION = "False";
      ENABLE_FOLLOW_UP_GENERATION = "False";
      GLOBAL_LOG_LEVEL = "DEBUG";
    };
  };

  systemd.services.open-webui = {
    path = with pkgs; [
      bash coreutils util-linux parted gptfdisk smartmontools nvme-cli lsof
      procps systemd curl jq git rclone networkmanager pciutils usbutils lm_sensors
    ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "root";
      Group = lib.mkForce "root";
      ProtectSystem = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      PrivateTmp = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      ProtectKernelTunables = lib.mkForce false;
      ProtectKernelModules = lib.mkForce false;
      ProtectKernelLogs = lib.mkForce false;
      ProtectControlGroups = lib.mkForce false;
      ProtectClock = lib.mkForce false;
      ProtectHostname = lib.mkForce false;
      ProtectProc = lib.mkForce "default";
      ProcSubset = lib.mkForce "all";
      RestrictNamespaces = lib.mkForce false;
      RestrictRealtime = lib.mkForce false;
      RestrictSUIDSGID = lib.mkForce false;
      SystemCallFilter = lib.mkForce [ ];
      CapabilityBoundingSet = lib.mkForce [ "~" ];
      NoNewPrivileges = lib.mkForce false;
      LockPersonality = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
      ReadOnlyPaths = lib.mkForce [ "/" ];
      ReadWritePaths = lib.mkForce [ "/var/lib/open-webui" "/tmp" "/run" "/dev/shm" ];
      DevicePolicy = lib.mkForce "auto";
      DeviceAllow = lib.mkForce [
        "block-* r"
        "char-drm rwm"
        "char-mem r"
        "char-pts rwm"
        "char-tty rwm"
        "char-usb_device r"
        "/dev/null rwm"
        "/dev/zero rwm"
        "/dev/random r"
        "/dev/urandom r"
        "/dev/tty rwm"
        "/dev/ptmx rwm"
      ];
      MemoryHigh = "30%";
      MemoryMax = "45%";
      TasksMax = 512;
      CPUWeight = 200;
      IOWeight = 200;
      Restart = "always";
      RestartSec = 2;
    };
  };

  systemd.services.ai-dynamic-provisioner = {
    description = "Découverte et pré-chargement asynchrone du modèle IA selon la RAM";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" "ollama.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${aiDynamicSelector}/bin/ai-dynamic-selector";
    };
  };

  systemd.services.ai-system-auditor = {
    description = "Audit IA bas niveau en accès root lecture seule stricte";
    after = [ "ollama.service" ];
    requires = [ "ollama.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ReadOnlyPaths = [ "/" ];
      ReadWritePaths = [ "/tmp" "/run" "/dev/shm" ];
      DevicePolicy = "auto";
      DeviceAllow = [
        "block-* r"
        "char-drm rwm"
        "char-mem r"
        "char-pts rwm"
        "char-tty rwm"
        "/dev/null rwm"
        "/dev/zero rwm"
        "/dev/urandom r"
      ];
      ExecStart = "${aiDiagScript}/bin/ai-diag";
    };
  };

  # =========================================================================
  # 9. GESTION DYNAMIQUE DES UTILISATEURS & ENVIRONNEMENT GRAPHIQUE KDE
  # =========================================================================
  users.mutableUsers = true;
  security.sudo.wheelNeedsPassword = false;

  system.activationScripts.detachDeclarativeUsers = {
    text = ''
      mkdir -p /var/lib/nixos
      rm -f /var/lib/nixos/declarative-users
      touch /var/lib/nixos/declarative-users
    '';
  };
  system.activationScripts.users.deps = [ "detachDeclarativeUsers" ];

  system.activationScripts.syncDynamicHumanUsers = {
    deps = [ "users" ];
    text = ''
      for NIXBLD in $(${pkgs.gawk}/bin/awk -F: '$1 ~ /^nixbld/ {print $1}' /etc/passwd); do
        for GRP in wheel disk networkmanager systemd-journal video podman lp scanner; do
          ${pkgs.shadow}/bin/gpasswd -d "$NIXBLD" "$GRP" >/dev/null 2>&1 || true
        done
      done

      HUMAN_USERS=$(${pkgs.gawk}/bin/awk -F: '$3 >= 1000 && $3 < 29000 && $1 !~ /^nixbld/ && $6 ~ /^\/home\// {print $1}' /etc/passwd)
      if [ -z "$HUMAN_USERS" ]; then
        ${pkgs.shadow}/bin/useradd -m -G wheel,disk,networkmanager,systemd-journal,video,podman,lp,scanner -s /run/current-system/sw/bin/bash utilisateur || true
        echo "utilisateur:bienvenu" | ${pkgs.shadow}/bin/chpasswd || true
      else
        for U in $HUMAN_USERS; do
          ${pkgs.shadow}/bin/usermod -aG wheel,disk,networkmanager,systemd-journal,video,podman,lp,scanner "$U" 2>/dev/null || true
        done
      fi
    '';
  };

  time.timeZone = lib.mkDefault "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "fr_FR.UTF-8";

  services.xserver.enable = true;
  services.xserver.xkb.layout = "fr";

  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;
  programs.dconf.enable = true;

  services.gnome.gnome-online-accounts.enable = true;
  services.gnome.evolution-data-server.enable = true;
  services.gvfs.enable = true;

  environment.pathsToLink = [
    "/share/accounts"
    "/lib/signon"
    "/lib/qt-6/plugins"
  ];

  systemd.user.services.kde-baloo.enable = false;

  environment.etc."xdg/autostart/plasma-win11-oem.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Provisionnement Bureau Windows 11 & Assistant OEM
    Exec=${plasmaWin11Setup}/bin/plasma-win11-setup
    OnlyShowIn=KDE;
    X-KDE-AutostartPhase=2
  '';

  systemd.user.services.chrome-clean-locks = {
    description = "Nettoyage dynamique des verrous SingletonLock orphelins de Chrome";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${browserWrapper}/bin/dynamic-browser --version";
    };
  };

  programs.firefox.enable = false;

  environment.shellAliases = {
    ls = "eza --icons";
    ll = "eza -la --icons --git";
    cat = "bat";
    find = "fd";
    ps = "procs";
    du = "dust";
    top = "btm";
  };
  programs.starship.enable = true;
  programs.zoxide.enable = true;

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "application/pdf" = "org.kde.okular.desktop";
      "application/x-ms-dos-executable" = "wine.desktop";
      "application/x-msi" = "wine.desktop";
    };
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = isX86;
    pulse.enable = true;
  };

  environment.systemPackages = (with pkgs; [
    customAiIcons
    aiDynamicSelector
    aiSidebarScript
    aiSidebarDesktop
    aiModelChooserGui
    aiModelChooserDesktop
    cloudAccountsManager
    cloudAccountsDesktop
    oemFirstBootWizard
    oemWizardDesktop
    factoryResetScript
    factoryResetDesktop
    plasmaWin11Setup
    aiDiagScript
    browserWrapper
    kdePackages.kdialog
    kdePackages.qttools
    networkmanagerapplet
    xdg-utils
    rclone
    fuse3
    gh
    jq
    curl
    inotify-tools
    clamav
    aide
    lynis
    bpftrace
    bcc
    tpm2-tools
    plocate
    recoll
    ripgrep-all
    tesseract
    ocrmypdf
    exiftool
    mediainfo
    ffmpeg
    btrfs-progs
    e2fsprogs
    duperemove
    jdupes
    rmlint
    bcache-tools
    lvm2
    borgbackup
    restic
    syncthing
    vdirsyncer
    isync
    nut
    mimalloc
    vmtouch
    gdb
    ethtool
    vnstat
    sysstat
    onlyoffice-desktopeditors
    thunderbird
    kdePackages.okular
    kdePackages.kcalc
    kdePackages.spectacle
    kdePackages.skanlite
    bitwarden-desktop
    localsend
    vlc
    gimp
    inkscape
    kdePackages.gwenview
    audacity
    obs-studio
    kdePackages.ark
    p7zip
    unrar
    unzip
    (lib.hiPrio uutils-coreutils-noprefix)
    ripgrep
    fd
    eza
    bat
    procs
    bottom
    dust
    zoxide
    sd
    zellij
    starship
    helix
    alacritty
    fzf
    lazygit
    lazydocker
    distrobox
    parted
    gptfdisk
    brightnessctl
    btop
    s-tui
    powertop
    lm_sensors
    nvme-cli
    smartmontools
    dmidecode
    pciutils
    usbutils
    file
    android-tools
    heimdall
    xrandr
    fluent-icon-theme
    git
    vim
    kdePackages.kaccounts-integration
    kdePackages.kaccounts-providers
    kdePackages.kio-gdrive
    kdePackages.signond
  ])
  ++ (optionalKdePkg "signon-plugin-oauth2")
  ++ (optionalKdePkg "signon-ui")
  ++ (optionalKdePkg "signon-kwallet-extension")
  ++ lib.optionals isX86 (with pkgs; [
    google-chrome
    wineWow64Packages.staging
    winetricks
    bottles
  ])
  ++ lib.optionals isAarch64 (with pkgs; [
    chromium
  ]);

  system.stateVersion = "26.05";
}
