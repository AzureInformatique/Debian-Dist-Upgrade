#!/bin/bash

# ---------------------------------------------------------------------
# Script de mise à niveau sécurisé vers Debian 12 (Bookworm)
# Fonctionnalités :
# - Sauvegardes complètes (config + données)
# - Simulation avec détection des suppressions
# - Annulation propre (rollback sources.list + suppression backup)
# - Confirmation manuelle à chaque étape critique
# ---------------------------------------------------------------------

if [ "$(id -u)" != "0" ]; then
  echo "Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

NOW=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/backup_debian_upgrade_$NOW"
LOG_FILE="$BACKUP_DIR/upgrade_simulation.log"
REMOVED_LIST="$BACKUP_DIR/removed_packages.txt"     

CRITICAL_SERVICES=(docker-ce mariadb-server apache2)

echo "📁 Création du répertoire de sauvegarde : $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

echo "🔐 Mise en attente des paquets critiques..."
for pkg in "${CRITICAL_SERVICES[@]}"; do
  apt-mark hold "$pkg" 2>/dev/null
done

echo "💾 Sauvegarde des fichiers de configuration système..."
cp -a /etc "$BACKUP_DIR/etc"
cp /var/spool/cron/crontabs/root "$BACKUP_DIR/root_cron" 2>/dev/null

echo "💾 Sauvegarde des données critiques..."
[ -d /var/lib/mysql ] && rsync -aAXv /var/lib/mysql "$BACKUP_DIR/mysql"
[ -d /var/lib/docker ] && rsync -aAXv /var/lib/docker "$BACKUP_DIR/docker"
[ -d /var/www ] && rsync -aAXv /var/www "$BACKUP_DIR/www"
[ -d /etc/letsencrypt ] && rsync -aAXv /etc/letsencrypt "$BACKUP_DIR/letsencrypt"

echo "🔄 Mise à jour des paquets installés..."
apt-get update
apt-get upgrade --with-new-pkgs -y

echo "📝 Sauvegarde de /etc/apt/sources.list (bullseye)"
cp /etc/apt/sources.list "$BACKUP_DIR/sources.list.bullseye"

echo "🛠️ Mise à niveau du fichier sources.list vers Debian 12..."
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
sed -i '/non-free/ {/non-free-firmware/! s/non-free/& non-free-firmware/}' /etc/apt/sources.list

echo "🔄 Mise à jour des dépôts pour Debian 12..."
apt-get update

echo "🔍 Simulation de la mise à niveau complète..."
apt-get dist-upgrade --simulate | tee "$LOG_FILE"

# 🔎 Extraction des suppressions détectées
grep "^Remv" "$LOG_FILE" | awk '{print $2}' > "$REMOVED_LIST"

if [ -s "$REMOVED_LIST" ]; then
  echo
  echo "❗ Paquets qui seraient supprimés lors de la mise à niveau :"
  while read -r pkg; do
    echo -e "  \033[0;31m- $pkg\033[0m"
  done < "$REMOVED_LIST"
  echo

  read -p "Voulez-vous continuer malgré ces suppressions ? (y/n): " confirm_removal
  if [[ "$confirm_removal" != "y" ]]; then
    echo "⚠️ Mise à niveau annulée par précaution."

    echo "🔁 Restauration de /etc/apt/sources.list (bullseye)..."
    cp "$BACKUP_DIR/sources.list.bullseye" /etc/apt/sources.list
    apt-get update

    echo "🗑️ Suppression de la sauvegarde créée à $BACKUP_DIR ..."
    read -p "Confirmez-vous la suppression de la sauvegarde ? (y/n): " delete_backup
    if [[ "$delete_backup" == "y" ]]; then
      rm -rf "$BACKUP_DIR"
      echo "✅ Sauvegarde supprimée."
    else
      echo "📁 Sauvegarde conservée dans $BACKUP_DIR"
    fi
    exit 0
  fi
else
  echo "✅ Aucun paquet ne serait supprimé selon la simulation."
fi

echo
read -p "Confirmez-vous la mise à niveau complète ? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "🚫 Mise à niveau annulée par l'utilisateur."

  echo "🔁 Restauration de /etc/apt/sources.list (bullseye)..."
  cp "$BACKUP_DIR/sources.list.bullseye" /etc/apt/sources.list
  apt-get update

  echo "🗑️ Suppression de la sauvegarde créée à $BACKUP_DIR ..."
  read -p "Confirmez-vous la suppression de la sauvegarde ? (y/n): " delete_backup
  if [[ "$delete_backup" == "y" ]]; then
    rm -rf "$BACKUP_DIR"
    echo "✅ Sauvegarde supprimée."
  else
    echo "📁 Sauvegarde conservée dans $BACKUP_DIR"
  fi
  exit 0
fi

echo "🔓 Déverrouillage temporaire des paquets critiques..."
for pkg in "${CRITICAL_SERVICES[@]}"; do
  apt-mark unhold "$pkg" 2>/dev/null
done

echo "🚀 Lancement de la mise à niveau complète..."
apt-get dist-upgrade -y

echo "🔐 Remise en attente des paquets critiques..."
for pkg in "${CRITICAL_SERVICES[@]}"; do
  apt-mark hold "$pkg" 2>/dev/null
done

echo "🔁 Redémarrage des services critiques..."
for service in php*-fpm apache2 mariadb redis-server coolwsd docker smbd ssh bind9; do
  systemctl restart "$service" >/dev/null 2>&1
done

echo
echo "✅ Mise à niveau terminée avec succès."
echo "📁 Sauvegardes disponibles dans : $BACKUP_DIR"
echo "📄 Rapport de simulation : $LOG_FILE"
[ -s "$REMOVED_LIST" ] && echo "🧾 Paquets supprimés identifiés dans : $REMOVED_LIST"

exit 0