# 🛠️ Script de Mise à Niveau Sécurisée vers Debian 12 (Bookworm)

Ce script Bash vous permet de réaliser une mise à niveau **sécurisée** et **interactive** d'un système Debian 11 (Bullseye) vers Debian 12 (Bookworm), en minimisant les risques grâce à des sauvegardes, simulations, et confirmations manuelles à chaque étape critique.

---

## ⚙️ Fonctionnalités

- 🔐 **Sauvegarde complète** des fichiers de configuration et des données critiques (MySQL, Docker, Apache, Let's Encrypt, etc.)
- 📝 **Simulation de mise à niveau** avec journal et détection des suppressions de paquets
- ❌ **Annulation automatique** si des suppressions critiques sont détectées ou si l'utilisateur refuse
- 🕹️ **Interactivité maximale** : confirmations manuelles à chaque étape importante
- ♻️ **Rollback rapide** du fichier `sources.list` en cas d'annulation
- 🧱 **Protection des services critiques** via `apt-mark hold`

---

## 📂 Sauvegardes

Les sauvegardes sont créées dans un dossier unique :

```bash
/root/backup_debian_upgrade_YYYYMMDD_HHMMSS/
