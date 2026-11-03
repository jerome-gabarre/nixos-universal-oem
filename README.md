# NixOS Universal OEM — Architecture Pyramidale GitOps (`x86_64` & `aarch64`)

Système d'exploitation **NixOS déclaratif, universel et agnostique**, conçu pour fonctionner à performance maximale et sans fuite mémoire sur n'importe quel PC portable, station de travail, serveur ou machine reconditionnée (`x86_64-linux` et `aarch64-linux`).

---

## 1. Caractéristiques d'Architecture (Les Piliers)

* **100 % Natif Rust & Go (Zéro script lent au démarrage)** : Tous les orchestrateurs système (`hardware-max-overdrive`, `ai-diag`, `system-self-healer`, `memory-leak-reaper`, `os-gitops-reconciler`, `rome-software-store`, `dynamic-browser`, `ai-sidebar`) sont compilés en binaires ELF Rust natifs (`pkgs.writers.writeRustBin`) interrogeant directement `/proc` et `/sys` en mémoire vive sans sous-processus.
* **Ordonnancement Hétérogène Asymétrique (`P-Cores` / `E-Cores`)** :
  * Détection dynamique de la topologie CPU au démarrage (`/run/os-topology/env`) sur architectures hybrides (Intel Core, AMD CCD, ARM64 big.LITTLE) ou homogènes.
  * **P-Cores (`AllowedCPUs=$P_CPUS`)** : Réservés à l'interface graphique Wayland, à l'audio temps réel PipeWire et au moteur d'inférence matricielle IA (`ollama.service`, `Nice=-10`, `CPUWeight=1000`).
  * **E-Cores (`AllowedCPUs=$E_CPUS`)** : Confinement strict des `workqueues` noyau et des démons de fond (`open-webui`, `clamav`, `osqueryd`, `fail2ban`, `rustdesk`, `nix-daemon`, `os-gitops-reconciler`, indexation OCR, snapshots et audits FIM).
* **Gestion Mémoire Agressive & Uptime Infini (Zéro Fuite)** :
  * Swap en RAM compressé **ZRAM (`zstd`, 150 %)** avec `vm.swappiness = 180` et `vm.page-cluster = 0`.
  * **MGLRU** (`min_ttl_ms = 1000`), déduplication mémoire **KSM** haute fréquence (`pages_to_scan = 2000`, `sleep_millisecs = 10`) et *Transparent HugePages* (`defer+madvise`).
  * Allocateurs bornés (`GLIBC_TUNABLES`, `MALLOC_ARENA_MAX=2`, `GOGC=50`, `GOMEMLIMIT`, `PYTHONMALLOC=malloc`) et démon Rust `memory-leak-reaper` réclamant la mémoire inactive via `cgroups v2` (`memory.reclaim`) toutes les 15 minutes.
* **IA Locale Auto-Calibrée & Audit Système en Lecture Seule** :
  * **Sélecteur Dynamique (`ai-dynamic-selector`)** : Détecte la VRAM dédiée et la RAM système au démarrage pour télécharger et précharger le modèle GGUF (`Q4_K_M`) optimal dans l'enveloppe mémoire.
  * **Sécurité Root Lecture Seule** : `ollama` et `open-webui` s'exécutent avec `ReadOnlyPaths = [ "/" ]` pour inspecter le système sans jamais pouvoir altérer l'OS.
  * **Bandeau IA (`ai-sidebar`)** : Interface latérale accessible en un clic sur l'icône **✨** de la barre des tâches.
* **Bibliothèque Logicielle Universelle ROME (14 Grands Domaines A–N)** :
  * Catalogue graphique natif en Rust (`rome-software-store`) couvrant les **1 923 fiches métiers France Travail (Domaines A à N)** ainsi que l'accès direct aux **120 000+ paquets NixOS** et à **Flathub**.
  * **Double mode d'exécution** : Installation persistante épinglée dans le profil utilisateur (avec création automatique de l'icône dans le menu KDE) ou lancement éphémère en flux tiré (`nix run`).
  * **Compatibilité Universelle** : Pont complet de bibliothèques partagées (`nix-ld`), support natif **AppImage** (`binfmt`), **Flatpak**, conteneurs **Podman/Distrobox** et exécution transparente des binaires **Windows `.exe` / `.msi`** (`binfmt` Wine).
* **Hub Universel des Comptes & Clouds FUSE (`cloud-accounts-manager`)** :
  * Montage temps réel dans `~/Clouds` avec cache VFS et auto-guérison (`system-self-healer` détectant et nettoyant les erreurs FUSE `ENOTCONN` / `EIO`) pour Google Drive, Microsoft OneDrive, Nextcloud/WebDAV, Dropbox, MEGA et Proton Drive.
* **Mode OEM Reconditionnement & Revente** :
  * Bureau **KDE Plasma 6 Wayland** pré-configuré au format Windows 11 sombre (`Fluent-dark`).
  * **Guide de Première Installation (`oem-first-boot-wizard`)** lancé automatiquement au premier démarrage d'un nouveau compte.
  * **Remise d'usine en 1 clic (`factory-reset-pc`)** : Efface toutes les données personnelles, historiques, comptes Cloud et Wi-Fi, puis recrée un compte client neuf (`utilisateur` / mot de passe : `bienvenu`).

---

## 2. Déploiement Universel sur un Nouveau PC (`x86_64` ou `aarch64`)

Le dépôt dissocie totalement la configuration système (`configuration.nix`, `universal-rome-suite.nix`) de l'empreinte matérielle locale (`/etc/nixos/hardware-configuration.nix`). Vous pouvez déployer ce dépôt sur n'importe quelle machine disposant d'une installation NixOS minimale.

### Sur un PC / Serveur `x86_64` (Intel / AMD)

Exécutez ce bloc unique dans un terminal :

    sudo mv /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix.keep
    sudo rm -rf /etc/nixos/* /etc/nixos/.* 2>/dev/null || true
    sudo git clone [https://github.com/jerome-gabarre/nixos-universal-oem.git](https://github.com/jerome-gabarre/nixos-universal-oem.git) /etc/nixos
    sudo mv /tmp/hardware-configuration.nix.keep /etc/nixos/hardware-configuration.nix
    echo "[https://github.com/jerome-gabarre/nixos-universal-oem.git](https://github.com/jerome-gabarre/nixos-universal-oem.git)" | sudo tee /etc/nixos/gitops-remote.url
    sudo git config --system --add safe.directory /etc/nixos
    sudo nixos-rebuild switch --flake /etc/nixos#universal --impure

### Sur une Machine `ARM64` (`aarch64-linux`)

Remplacez uniquement la cible finale par `#universal-arm64` :

    sudo nixos-rebuild switch --flake /etc/nixos#universal-arm64 --impure

---

## 3. Commandes Utiles & Outils Intégrés

### Applications Graphiques & Lanceurs Rapides

| Commande / Lanceur | Rôle |
| :--- | :--- |
| `rome-software-store` | Ouvre la **Bibliothèque Logicielle Métier ROME (A–N)** (NixOS & Flathub) |
| `ai-sidebar` | Ouvre le **Bandeau Latéral IA ✨** (Open-WebUI connecté à Ollama local) |
| `ai-model-selector` | Ouvre le **Catalogue des Modèles IA ★** (changement de modèle GGUF à chaud) |
| `cloud-accounts-manager` | Ouvre le **Hub Universel des Comptes & Clouds ☁️** (montage FUSE dans `~/Clouds`) |
| `oem-first-boot-wizard` | Relance le **Guide de Première Installation** |
| `factory-reset-pc` | Lance la **Remise à zéro d'usine (Mode Revente)** |

### Diagnostic Matériel, Topologie & Audit IA (San Gen Shugi)

    # Consulter la topologie matérielle détectée au démarrage (P-Cores, E-Cores, Cache L2, VRAM)
    cat /run/os-topology/env

    # Consulter les paramètres dynamiques injectés dans Ollama
    cat /run/ollama-dynamic.env

    # Lancer un audit matériel complet en Rust (9 sondes /proc & /sys + synthèse IA en 4 points)
    sudo systemctl start ai-system-auditor.service
    journalctl -u ai-system-auditor.service -n 35 --no-pager

### Gestion et Réconciliation GitOps

Le timer `os-gitops-reconciler.timer` vérifie automatiquement toutes les 6 heures si un nouveau commit a été poussé sur la branche `main` du dépôt GitHub et applique la mise à jour en tâche de fond sur les `E-Cores`.

    # Déclencher une synchronisation GitOps immédiate
    sudo systemctl start os-gitops-reconciler.service
    journalctl -u os-gitops-reconciler.service -n 20 --no-pager

    # Forcer une reconstruction complète même si le commit Git local est identique au distant
    sudo os-gitops-reconciler --force

---

## 4. Workflow Administrateur (Modifier et Publier une Mise à Jour)

Lorsque vous modifiez la configuration sur votre machine maîtresse pour la propager à l'ensemble de vos machines :

    cd /etc/nixos
    sudo nixos-rebuild switch --flake /etc/nixos#universal --impure
    git add flake.nix flake.lock configuration.nix universal-rome-suite.nix README.md
    git commit -m "feat: description de la modification"
    git push

---

## 5. Structure du Dépôt

* `flake.nix` : Point d'entrée déclaratif multi-architecture (`universal` pour `x86_64-linux`, `universal-arm64` pour `aarch64-linux`) avec chargement dynamique du `/etc/nixos/hardware-configuration.nix` local.
* `configuration.nix` : Noyau Zen/Latest, sécurité AppArmor/Auditd/ClamAV/AIDE/Lynis, gestion mémoire ZRAM/MGLRU/KSM, démon topologique Rust `hardware-max-overdrive`, auto-guérison `system-self-healer`, purge mémoire `memory-leak-reaper`, pile IA Ollama/Open-WebUI, Hub Cloud FUSE et bureau KDE Plasma 6 Windows 11.
* `universal-rome-suite.nix` : Pont universel `nix-ld` + `AppImage`, démon de réconciliation Rust `os-gitops-reconciler`, démon permanent `rustdesk` et magasin logiciel Rust `rome-software-store` couvrant les 14 grands domaines ROME.
* `.gitignore` : Exclut `hardware-configuration.nix` et `gitops-remote.url` pour garantir que le dépôt reste 100 % agnostique du matériel.
