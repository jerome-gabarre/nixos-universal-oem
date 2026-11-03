# /etc/nixos/universal-rome-suite.nix
{ config, pkgs, lib, ... }:

let
  isX86 = pkgs.stdenv.hostPlatform.isx86_64;

  # 1. BINAIRE ELF RUST NATIF : Magasin & Bibliothèque Logicielle Universelle ROME (14 Grands Domaines A-N)
  romeSoftwareStore = pkgs.writers.writeRustBin "rome-software-store" {} ''
    use std::fs;
    use std::process::Command;

    const KDIALOG: &str = "${pkgs.kdePackages.kdialog}/bin/kdialog";
    const NIX_BIN: &str = "${pkgs.nix}/bin/nix";
    const FLATPAK_BIN: &str = "${pkgs.flatpak}/bin/flatpak";

    fn run_kdialog(args: &[&str]) -> Option<String> {
        let out = Command::new(KDIALOG).args(args).output().ok()?;
        if out.status.success() {
            Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
        } else {
            None
        }
    }

    fn notify(msg: &str) {
        let _ = Command::new(KDIALOG)
            .args(["--title", "Bibliothèque Universelle ROME", "--passivepopup", msg, "5"])
            .spawn();
    }

    fn install_or_run_packages(pkgs_list: &[&str], persistent: bool) {
        let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
        let state_dir = format!("{}/.config/rome-software-store", home);
        let _ = fs::create_dir_all(&state_dir);
        let manifest_path = format!("{}/installed-packages.txt", state_dir);

        if persistent {
            notify(&format!("Installation persistante en cours ({} paquet(s))...", pkgs_list.len()));
            let mut install_args = vec![
                "--extra-experimental-features", "nix-command flakes",
                "profile", "install", "--impure"
            ];
            let flake_refs: Vec<String> = pkgs_list.iter().map(|p| format!("nixpkgs#{}", p)).collect();
            for r in &flake_refs {
                install_args.push(r.as_str());
            }
            let status = Command::new(NIX_BIN).args(&install_args).status();
            if status.map(|s| s.success()).unwrap_or(false) {
                let mut current = fs::read_to_string(&manifest_path).unwrap_or_default();
                for p in pkgs_list {
                    if !current.lines().any(|l| l.trim() == *p) {
                        current.push_str(&format!("{}\n", p));
                    }
                }
                let _ = fs::write(&manifest_path, current);
                let _ = run_kdialog(&[
                    "--title", "Installation terminée",
                    "--msgbox", &format!("Les logiciels suivants sont installés de façon permanente et ajoutés au menu Démarrer KDE :\n• {}", pkgs_list.join("\n• "))
                ]);
            } else {
                let _ = run_kdialog(&[
                    "--title", "Erreur d'installation",
                    "--error", "Un ou plusieurs paquets n'ont pas pu être installés depuis nixpkgs."
                ]);
            }
        } else if let Some(first_pkg) = pkgs_list.first() {
            notify(&format!("Lancement éphémère en flux tiré de « {} »...", first_pkg));
            let _ = Command::new(NIX_BIN)
                .args([
                    "--extra-experimental-features", "nix-command flakes",
                    "run", "--impure",
                    &format!("nixpkgs#{}", first_pkg)
                ])
                .spawn();
        }
    }

    fn select_domain_packages(domain_code: &str) {
        let (title, items): (&str, Vec<(&str, &str, &str)>) = match domain_code {
            "A" => (
                "Domaine A — Agriculture, Espaces naturels, Forêt & SIG (107 fiches ROME)",
                vec![
                    ("qgis", "QGIS — Système d'Information Géographique, parcelles & topographie", "on"),
                    ("grass", "GRASS GIS — Modélisation hydrologique, sols & télédétection", "off"),
                    ("stellarium", "Stellarium — Éphémérides, astronomie & orientation", "off"),
                    ("homebank", "HomeBank — Gestion financière d'exploitation agricole", "off"),
                ]
            ),
            "B" => (
                "Domaine B — Arts, Façonnage d'ouvrages d'art & Design (54 fiches ROME)",
                vec![
                    ("krita", "Krita — Peinture numérique, illustration & textures", "on"),
                    ("blender", "Blender — Modélisation 3D, sculpture, rendu & bijouterie", "on"),
                    ("darktable", "Darktable — Développement RAW & laboratoire photographique", "off"),
                    ("fontforge", "FontForge — Création typographique & gravure de polices", "off"),
                    ("freecad", "FreeCAD — Conception paramétrique d'ouvrages d'art", "off"),
                ]
            ),
            "C" => (
                "Domaine C — Banque, Assurance, Finance & Immobilier (64 fiches ROME)",
                vec![
                    ("gnucash", "GnuCash — Comptabilité en partie double, états financiers & bilans", "on"),
                    ("homebank", "HomeBank — Analyse budgétaire, amortissements & trésorerie", "on"),
                    ("pdfarranger", "PDF Arranger — Assemblage et fusion de dossiers clients PDF", "off"),
                    ("keepassxc", "KeePassXC — Coffre-fort cryptographique de secrets bancaires", "off"),
                ]
            ),
            "D" => (
                "Domaine D — Commerce, Vente & Grande distribution (140 fiches ROME)",
                vec![
                    ("homebank", "HomeBank — Suivi de caisse, marges & trésorerie commerciale", "on"),
                    ("scribus", "Scribus — PAO pour catalogues, brochures & PLV magasin", "on"),
                    ("zbar", "ZBar — Lecture et décodage de codes-barres / QR codes", "off"),
                    ("glabels-qt", "gLabels — Création d'étiquettes prix, codes-barres & publipostage", "off"),
                ]
            ),
            "E" => (
                "Domaine E — Communication, Média, Audio/Vidéo & Multimédia (79 fiches ROME)",
                vec![
                    ("kdenlive", "Kdenlive — Montage vidéo professionnel non-linéaire", "on"),
                    ("ardour", "Ardour — Station audionumérique multipiste (DAW)", "off"),
                    ("scribus", "Scribus — Mise en page professionnelle & imprimerie (PAO)", "on"),
                    ("darktable", "Darktable — Post-traitement photographique professionnel", "off"),
                    ("handbrake", "HandBrake — Transcodage et compression vidéo multi-formats", "off"),
                ]
            ),
            "F" => (
                "Domaine F — Construction, Bâtiment & Travaux Publics (114 fiches ROME)",
                vec![
                    ("freecad", "FreeCAD — Modélisation BIM/CAO 3D bâtiment & charpente", "on"),
                    ("librecad", "LibreCAD — Plans 2D cotés (DXF/DWG), métrés & schémas électriques", "on"),
                    ("qgis", "QGIS — Géomatique, cadastre, VRD & terrassement", "off"),
                    ("sweet-home-3d", "Sweet Home 3D — Aménagement intérieur & plans d'exécution", "off"),
                ]
            ),
            "G" => (
                "Domaine G — Hôtellerie-Restauration, Tourisme & Loisirs (119 fiches ROME)",
                vec![
                    ("homebank", "HomeBank — Gestion des coûts matières, caisse & trésorerie CHR", "on"),
                    ("scribus", "Scribus — Création de menus, cartes & supports touristiques", "on"),
                    ("qgis", "QGIS — Cartographie d'itinéraires, randonnées & patrimoine", "off"),
                ]
            ),
            "H" => (
                "Domaine H — Industrie, Usinage, Mécanique & Électronique (280 fiches ROME)",
                vec![
                    ("freecad", "FreeCAD — CAO mécanique paramétrique, parcours d'outils FAO/CAM & FEM", "on"),
                    ("openscad", "OpenSCAD — Modélisation 3D industrielle par script déclaratif", "off"),
                    ("librecad", "LibreCAD — Dessin industriel 2D & découpe laser/jet d'eau", "on"),
                    ("kicad", "KiCad — Conception électronique EDA, schémas & routage PCB", "off"),
                    ("octave", "GNU Octave — Calcul matriciel, asservissement & traitement du signal", "off"),
                ]
            ),
            "I" => (
                "Domaine I — Installation, Maintenance, Diagnostic & Réseaux (134 fiches ROME)",
                vec![
                    ("remmina", "Remmina — Télémaintenance multi-protocoles (RDP, VNC, SSH)", "on"),
                    ("minicom", "Minicom — Console série RS232/UART automates & équipements industriels", "on"),
                    ("picocom", "Picocom — Terminal série léger pour diagnostic embarqué", "off"),
                    ("nmap", "Nmap — Cartographie et diagnostic de réseaux industriels", "off"),
                ]
            ),
            "J" => (
                "Domaine J — Santé, Imagerie Médicale & Recherche Clinique (86 fiches ROME)",
                vec![
                    ("aeskulap", "Aeskulap — Visualiseur d'imagerie médicale DICOM (Radio/Scanner/IRM)", "on"),
                    ("keepassxc", "KeePassXC — Protection chiffrée des accès et mots de passe santé", "on"),
                    ("pdfarranger", "PDF Arranger — Gestion documentaire de dossiers médicaux PDF", "off"),
                ]
            ),
            "K" => (
                "Domaine K — Services à la personne, Collectivité & Éducation (319 fiches ROME)",
                vec![
                    ("pdfarranger", "PDF Arranger — Réorganisation, fusion et découpage de documents PDF", "on"),
                    ("texstudio", "TeXstudio — Édition scientifique et académique LaTeX", "off"),
                    ("kalzium", "Kalzium — Classification périodique et enseignement scientifique", "off"),
                ]
            ),
            "L" => (
                "Domaine L — Spectacle, Son, Lumière & Régie Scénique (72 fiches ROME)",
                vec![
                    ("ardour", "Ardour — Enregistrement multipiste, mixage & régie sonore", "on"),
                    ("qlcplus", "QLC+ — Pupitre de commande d'éclairage scénique DMX512 / Art-Net", "on"),
                    ("kdenlive", "Kdenlive — Création vidéo scénographique & habillage visuel", "off"),
                    ("blender", "Blender — Scénographie 3D et prévisualisation de plateau", "off"),
                ]
            ),
            "M" => (
                "Domaine M — Support à l'entreprise, IT, DevOps & Comptabilité (222 fiches ROME)",
                vec![
                    ("vscodium", "VSCodium — Environnement de développement intégré (IDE sans télémétrie)", "on"),
                    ("dbeaver-bin", "DBeaver — Administration universelle de bases de données SQL/NoSQL", "on"),
                    ("gnucash", "GnuCash — Comptabilité générale et analytique d'entreprise", "off"),
                    ("libreoffice-qt", "LibreOffice Suite — Suite bureautique complémentaire (Calc/Base/Writer)", "off"),
                ]
            ),
            "N" => (
                "Domaine N — Transport, Logistique & Mobilité (133 fiches ROME)",
                vec![
                    ("qgis", "QGIS — Analyse de réseaux routiers, tournées & bassins logistiques", "on"),
                    ("josm", "JOSM — Éditeur cartographique avancé OpenStreetMap", "off"),
                    ("homebank", "HomeBank — Suivi des coûts de flotte et gestion de parc", "off"),
                ]
            ),
            _ => return,
        };

        let mut args = vec![
            "--title", title,
            "--geometry", "880x520",
            "--separate-output",
            "--checklist",
            "Cochez les logiciels métiers à installer ou exécuter depuis la bibliothèque NixOS :"
        ];
        for (pkg, desc, state) in &items {
            args.push(pkg);
            args.push(desc);
            args.push(state);
        }

        if let Some(selection) = run_kdialog(&args) {
            let chosen: Vec<&str> = selection.lines().map(|s| s.trim()).filter(|s| !s.is_empty()).collect();
            if chosen.is_empty() {
                return;
            }
            let mode = run_kdialog(&[
                "--title", "Mode d'activation logiciel",
                "--geometry", "680x300",
                "--menu",
                "Comment souhaitez-vous utiliser les logiciels sélectionnés ?",
                "install", "📌 Installer définitivement (Épinglé dans le menu KDE + résiste au nettoyage)",
                "ephemeral", "⚡ Lancer une seule fois en Flux Tiré (Exécution immédiate sans installation)"
            ]);
            match mode.as_deref() {
                Some("install") => install_or_run_packages(&chosen, true),
                Some("ephemeral") => install_or_run_packages(&chosen, false),
                _ => {}
            }
        }
    }

    fn main() {
        let action = run_kdialog(&[
            "--title", "Bibliothèque Logicielle Universelle ROME (1 923 Métiers — 120 000+ Paquets)",
            "--geometry", "920x640",
            "--menu",
            "Sélectionnez votre Grand Domaine Professionnel ROME ou recherchez un logiciel spécifique :\n(Tous les environnements Linux, AppImage, Flatpak et Windows .exe sont supportés nativement)",
            "SEARCH", "🔍 Recherche directe / Commande libre (Piocher dans les 120 000+ paquets NixOS)",
            "FLATPAK", "📦 Installer une application universelle depuis Flathub (ID ou nom Flatpak)",
            "LIST", "📋 Gérer / Désinstaller mes logiciels métiers installés",
            "A", "🌿 A — Agriculture, Pêche, Forêts, Espaces verts & SIG (107 métiers ROME)",
            "B", "🎨 B — Arts, Façonnage d'ouvrages d'art & Création 3D (54 métiers ROME)",
            "C", "🏦 C — Banque, Assurance, Comptabilité & Immobilier (64 métiers ROME)",
            "D", "🛒 D — Commerce, Vente & Grande distribution (140 métiers ROME)",
            "E", "🎬 E — Communication, Média, Audio/Vidéo & PAO (79 métiers ROME)",
            "F", "🏗️ F — Construction, Bâtiment, Architecture & Travaux Publics (114 métiers ROME)",
            "G", "🍽️ G — Hôtellerie-Restauration, Tourisme & Animation (119 métiers ROME)",
            "H", "⚙️ H — Industrie, Usinage CAO/FAO, Électronique & Calcul (280 métiers ROME)",
            "I", "🔧 I — Installation, Maintenance, Réseaux & Diagnostic Série (134 métiers ROME)",
            "J", "🩺 J — Santé, Imagerie Médicale DICOM & Clinique (86 métiers ROME)",
            "K", "🏛️ K — Services à la personne, Collectivité, Recherche & Éducation (319 métiers ROME)",
            "L", "🎭 L — Spectacle, Régie Son/Lumière DMX & Scénographie (72 métiers ROME)",
            "M", "💻 M — Support à l'entreprise, Ingénierie IT, DevOps & Data (222 métiers ROME)",
            "N", "🚚 N — Transport, Logistique & Cartographie Routière (133 métiers ROME)"
        ]);

        match action.as_deref() {
            Some("SEARCH") => {
                if let Some(query) = run_kdialog(&[
                    "--title", "Recherche et Installation Directe (120 000+ Paquets NixOS)",
                    "--geometry", "780x420",
                    "--inputbox",
                    "Entrez le nom d'un ou plusieurs paquets NixOS séparés par un espace\n(ex: freecad, qgis, kicad, blender, gnucash, octave, wireshark, obs-studio) :"
                ]) {
                    let pkgs_list: Vec<&str> = query.split_whitespace().collect();
                    if !pkgs_list.is_empty() {
                        let mode = run_kdialog(&[
                            "--title", "Mode d'exécution",
                            "--menu", "Choisissez le mode d'utilisation :",
                            "install", "📌 Installer de façon permanente dans mon profil (Menu KDE)",
                            "ephemeral", "⚡ Exécuter immédiatement en Flux Tiré (Sans installation)"
                        ]);
                        install_or_run_packages(&pkgs_list, mode.as_deref() == Some("install"));
                    }
                }
            }
            Some("FLATPAK") => {
                if let Some(app_id) = run_kdialog(&[
                    "--title", "Installation Universelle Flathub",
                    "--inputbox",
                    "Entrez le nom ou l'identifiant Flathub de l'application (ex: org.freecad.FreeCAD, com.ultimaker.cura) :"
                ]) {
                    if !app_id.is_empty() {
                        notify(&format!("Installation Flatpak de « {} » en cours...", app_id));
                        let _ = Command::new(FLATPAK_BIN)
                            .args(["install", "--user", "-y", "flathub", &app_id])
                            .status();
                    }
                }
            }
            Some("LIST") => {
                let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/tmp"));
                let manifest_path = format!("{}/.config/rome-software-store/installed-packages.txt", home);
                let content = fs::read_to_string(&manifest_path).unwrap_or_default();
                let lines: Vec<&str> = content.lines().filter(|l| !l.trim().is_empty()).collect();
                if lines.is_empty() {
                    let _ = run_kdialog(&[
                        "--title", "Logiciels installés",
                        "--msgbox", "Aucun logiciel additionnel n'est actuellement épinglé dans votre profil utilisateur."
                    ]);
                } else if let Some(to_remove) = run_kdialog(&[
                    "--title", "Gérer mes logiciels installés",
                    "--inputbox",
                    &format!("Logiciels actuellement installés :\n• {}\n\nPour en désinstaller un, entrez son nom exact ci-dessous :", lines.join("\n• "))
                ]) {
                    let target = to_remove.trim();
                    if !target.is_empty() {
                        let _ = Command::new(NIX_BIN)
                            .args(["--extra-experimental-features", "nix-command flakes", "profile", "remove", target])
                            .status();
                        let updated: String = lines.into_iter().filter(|l| *l != target).map(|l| format!("{}\n", l)).collect();
                        let _ = fs::write(&manifest_path, updated);
                        notify(&format!("Le logiciel « {} » a été retiré du profil.", target));
                    }
                }
            }
            Some(code) => select_domain_packages(code),
            None => {}
        }
    }
  '';

  romeSoftwareStoreDesktop = pkgs.makeDesktopItem {
    name = "rome-universal-launcher";
    desktopName = "Bibliothèque Logicielle Métier (ROME A–N)";
    comment = "Piocher, installer ou lancer à la volée les logiciels des 14 grands domaines métiers ROME";
    exec = "${romeSoftwareStore}/bin/rome-software-store";
    icon = "system-software-install";
    categories = [ "System" "Utility" ];
  };

  # 2. BINAIRE ELF RUST NATIF : Démon Hybride (Mode 1 Souverain NixOS Officiel / Mode 2 & 3 Flotte GitOps)
  osGitopsReconciler = pkgs.writers.writeRustBin "os-gitops-reconciler" {} ''
    use std::fs;
    use std::path::Path;
    use std::process::Command;

    const GIT: &str = "${pkgs.git}/bin/git";
    const NIX: &str = "${pkgs.nix}/bin/nix";
    const NIXOS_REBUILD: &str = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
    const NIXOS_GEN_CFG: &str = "${pkgs.nixos-install-tools}/bin/nixos-generate-config";

    fn run_status(bin: &str, args: &[&str], dir: &str) -> bool {
        Command::new(bin)
            .current_dir(dir)
            .args(args)
            .status()
            .map(|s| s.success())
            .unwrap_or(false)
    }

    fn run_output(bin: &str, args: &[&str], dir: &str) -> String {
        Command::new(bin)
            .current_dir(dir)
            .args(args)
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_default()
    }

    fn main() {
        let repo_dir = "/etc/nixos";
        let _ = fs::create_dir_all(repo_dir);

        if !Path::new("/etc/nixos/hardware-configuration.nix").exists() {
            println!("[GitOps Rust] Génération initiale de /etc/nixos/hardware-configuration.nix...");
            let _ = Command::new(NIXOS_GEN_CFG).args(["--dir", repo_dir]).status();
        }

        let flake_target = match std::env::consts::ARCH {
            "aarch64" => "universal-arm64",
            _ => "universal",
        };
        let flake_uri = format!("/etc/nixos#{}", flake_target);
        let force_apply = std::env::args().any(|a| a == "--force");

        let remote_cfg = fs::read_to_string("/etc/nixos/gitops-remote.url")
            .unwrap_or_default()
            .trim()
            .to_string();

        // CAS A : Mode Flotte GitOps (uniquement si /etc/nixos/gitops-remote.url est défini)
        if !remote_cfg.is_empty() {
            if !Path::new("/etc/nixos/.git").exists() {
                let _ = run_status(GIT, &["init", "-b", "main"], repo_dir);
                let _ = run_status(GIT, &["remote", "add", "origin", &remote_cfg], repo_dir);
            }

            // Protection contre l'écrasement de modifications locales en cours
            let dirty = run_output(GIT, &["status", "--porcelain"], repo_dir);
            if !dirty.is_empty() && !force_apply {
                println!("[GitOps Rust] Modifications locales détectées dans /etc/nixos : synchronisation distante ignorée par sécurité.");
                return;
            }

            if run_status(GIT, &["fetch", "--all", "--prune"], repo_dir) {
                let local_rev = run_output(GIT, &["rev-parse", "HEAD"], repo_dir);
                let remote_rev = run_output(GIT, &["rev-parse", "@{u}"], repo_dir);

                if !remote_rev.is_empty() && local_rev == remote_rev && !force_apply {
                    println!("[GitOps Rust] Système déjà synchronisé sur le commit {} ({}).", local_rev, flake_target);
                    return;
                }

                if !remote_rev.is_empty() && local_rev != remote_rev {
                    println!("[GitOps Rust] Nouveau commit validé détecté ({} -> {}), mise à jour...", local_rev, remote_rev);
                    let _ = run_status(GIT, &["reset", "--hard", "@{u}"], repo_dir);
                }
            }
        } else {
            // CAS B : Mode Souverain Autonome (Dons, Particuliers B2C, Entreprises sans serveur Git externe)
            if !force_apply {
                println!("[Mode Souverain Rust] Aucun dépôt tiers lié. Vérification des mises à jour de sécurité officielles NixOS...");
                let before_lock = fs::read_to_string("/etc/nixos/flake.lock").unwrap_or_default();
                let _ = run_status(NIX, &["--extra-experimental-features", "nix-command flakes", "flake", "update", "--flake", repo_dir], repo_dir);
                let after_lock = fs::read_to_string("/etc/nixos/flake.lock").unwrap_or_default();
                if before_lock == after_lock {
                    println!("[Mode Souverain Rust] Le système est déjà à jour avec le canal officiel NixOS.");
                    return;
                }
            }
        }

        println!("[GitOps Rust] Application déclarative de {}...", flake_uri);
        let ok = Command::new(NIXOS_REBUILD)
            .args(["switch", "--flake", &flake_uri, "--impure"])
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if ok {
            println!("[GitOps Rust] Mise à jour atomique réussie sur la cible {}.", flake_target);
        } else {
            eprintln!("[GitOps Rust] Échec de la mise à jour : la génération précédente reste intacte.");
            std::process::exit(1);
        }
    }
  '';

  # 3. BINAIRE ELF RUST NATIF : Nettoyage pré-démarrage de RustDesk (Zéro sed / Zéro Bash)
  rustdeskPreSanitize = pkgs.writers.writeRustBin "rustdesk-pre-sanitize" {} ''
    use std::fs;
    use std::path::PathBuf;

    fn sanitize_file(path: &PathBuf, mode: &str) {
        if let Ok(content) = fs::read_to_string(path) {
            let updated = if mode == "drop_ws" {
                content
                    .lines()
                    .filter(|l| !l.contains("allow-websocket"))
                    .map(|l| format!("{}\n", l))
                    .collect::<String>()
            } else {
                content.replace("\"isMaximized\":true", "\"isMaximized\":false")
            };
            if updated != content {
                let _ = fs::write(path, updated);
            }
        }
    }

    fn main() {
        if let Ok(entries) = fs::read_dir("/tmp") {
            for e in entries.flatten() {
                let name = e.file_name().to_string_lossy().to_lowercase();
                if name.starts_with("rustdesk") {
                    let _ = fs::remove_dir_all(e.path());
                    let _ = fs::remove_file(e.path());
                }
            }
        }

        let mut roots = vec![PathBuf::from("/root")];
        if let Ok(homes) = fs::read_dir("/home") {
            for h in homes.flatten() {
                roots.push(h.path());
            }
        }

        for r in roots {
            let dir = r.join(".config/rustdesk");
            sanitize_file(&dir.join("RustDesk2.toml"), "drop_ws");
            sanitize_file(&dir.join("RustDesk_local.toml"), "unmaximize");
        }
    }
  '';

  # 4. WEBAPP NATIVE : Google Chrome Bureau à Distance (WebRTC)
  chromeRemoteDesktopWebApp = pkgs.makeDesktopItem {
    name = "chrome-remote-desktop-web";
    desktopName = "Google Chrome Bureau à Distance";
    comment = "Accès et assistance à distance via Google Chrome (WebRTC)";
    exec = "dynamic-browser --app=https://remotedesktop.google.com/access";
    icon = "google-chrome";
    categories = [ "Network" "RemoteAccess" ];
  };
in
{
  # =========================================================================
  # 1. PONT UNIVERSEL DE BIBLIOTHÈQUES PARTAGÉES (NIX-LD ÉTENDU & APPIMAGE)
  # =========================================================================
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.git = {
    enable = true;
    config.safe.directory = "/etc/nixos";
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      glibc
      zlib
      zstd
      xz
      bzip2
      lz4
      openssl
      curl
      libxml2
      libxslt
      sqlite
      libffi
      util-linux
      systemd
      dbus
      attr
      acl
      libcap
      libseccomp
      libGL
      libGLU
      vulkan-loader
      wayland
      libxkbcommon
      libdrm
      mesa
      libx11
      libxext
      libxrender
      libxi
      libxcursor
      libxrandr
      libxfixes
      libxcomposite
      libxdamage
      libxtst
      libxscrnsaver
      libxcb
      libxcb-util
      libxcb-image
      libxcb-keysyms
      libxcb-render-util
      libxcb-wm
      glib
      gtk3
      pango
      cairo
      gdk-pixbuf
      atk
      harfbuzz
      freetype
      fontconfig
      alsa-lib
      pipewire
      libpulseaudio
      libusb1
      hidapi
      libv4l
      v4l-utils
      udev
      nspr
      nss
      cups
    ];
  };

  boot.kernelModules = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="ttyUSB[0-9]*|ttyACM[0-9]*", MODE="0666", GROUP="wheel", TAG+="uaccess"
    KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="wheel", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

  networking.firewall.allowedTCPPorts = [ 21118 ];
  networking.firewall.allowedUDPPorts = [ 21119 ];

  # =========================================================================
  # 2. RÉCONCILIATEUR HYBRIDE (SOUVERAIN NIXOS / GITOPS SUR LES E-CORES)
  # =========================================================================
  systemd.services.os-gitops-reconciler = {
    description = "Moteur de Mise à Jour Atomique & Réconciliation GitOps en Rust Natif";
    after = [ "network-online.target" "hardware-max-overdrive.service" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ git nix nixos-rebuild nixos-install-tools coreutils systemd ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      CPUWeight = 10;
      IOSchedulingClass = "idle";
      IOWeight = 10;
      MemoryHigh = "2G";
      MemoryMax = "4G";
      ExecStart = "${osGitopsReconciler}/bin/os-gitops-reconciler";
    };
  };

  systemd.timers.os-gitops-reconciler = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };

  # =========================================================================
  # 3. DÉMON PERMANENT RUSTDESK (100% RUST ELF PRE-SANITIZE & WAYLAND PORTAL)
  # =========================================================================
  systemd.services.rustdesk = {
    description = "Démon système RustDesk (Service réseau & uinput 24/7)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "systemd-logind.service" ];
    wants = [ "network-online.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Type = "simple";
      Environment = [
        "PATH=/run/wrappers/bin:/run/current-system/sw/bin:${lib.makeBinPath (with pkgs; [ bash coreutils procps util-linux systemd shadow sudo xdg-utils rustdesk-flutter ])}"
      ];
      ExecStartPre = "${rustdeskPreSanitize}/bin/rustdesk-pre-sanitize";
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      MemoryHigh = "256M";
      MemoryMax = "512M";
      TasksMax = 128;
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.user.services.rustdesk-unattended-portal-auth = {
    description = "Autorisation automatique du partage d'écran sans surveillance sous KDE Plasma 6 Wayland & Initialisation Flathub";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "rustdesk-and-flathub-init" ''
        ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
        ${pkgs.flatpak}/bin/flatpak permission-set kde-authorized remote-desktop "" yes || true
        ${pkgs.flatpak}/bin/flatpak permission-set kde-authorized remote-desktop "rustdesk" yes || true
        ${pkgs.flatpak}/bin/flatpak permission-set kde-authorized remote-desktop "com.rustdesk.RustDesk" yes || true
      '';
    };
  };

  # =========================================================================
  # 4. SOCLE MÉTIER TRANSVERSAL & MAGASIN ROME EN FLUX TIRÉ
  # =========================================================================
  programs.wireshark.enable = true;

  environment.systemPackages = (with pkgs; [
    romeSoftwareStore
    romeSoftwareStoreDesktop
    osGitopsReconciler
    wl-clipboard
    xclip
    comma
    nix-index
    chromeRemoteDesktopWebApp
    rustdesk-flutter
    kdePackages.krfb
    remmina
    minicom
    picocom
    pdfarranger
    keepassxc
  ]) ++ lib.optionals isX86 (with pkgs; [
    orca-slicer
  ]);
}
