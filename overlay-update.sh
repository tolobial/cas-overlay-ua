#!/bin/bash
# =====================================================================
# 🧱 Script de mise à jour Overlay CAS – Université des Antilles
# Auteur : équipe SSO / IAM - Université des Antilles
# Version : 1.0
# Objet : Automatiser la mise à jour, le build, l’archivage et le déploiement du CAS overlay
# =====================================================================

# --- CONFIGURATION GÉNÉRALE ---
CAS_VERSION=${1:-7.3.0}
DATE=$(date +%Y%m%d-%H%M)
BUILD_DIR="build/libs"
WAR_NAME="cas.war"
ARCHIVE_DIR="archives"
TOMCAT_WEBAPPS="/var/lib/tomcat10/webapps"
TOMCAT_SERVICE="tomcat10"
CAS_DEPLOY_DIR="$TOMCAT_WEBAPPS/ROOT"
GRADLE_PROPS="gradle.properties"

# --- FONCTIONS UTILITAIRES ---
banner() {
  echo "------------------------------------------------------------"
  echo " $1"
  echo "------------------------------------------------------------"
}

fail() {
  echo "❌ $1"
  exit 1
}

success() {
  echo "✅ $1"
}

# =====================================================================
# ÉTAPE 1 : Vérification de l’environnement overlay
# =====================================================================
banner "Vérification de l'environnement Overlay"

# Vérifie que le script est bien exécuté à la racine de l’overlay
[ -f "$GRADLE_PROPS" ] || fail "Fichier gradle.properties introuvable. Exécute ce script depuis la racine de ton overlay."

# Vérifie la présence de Gradle Wrapper
[ -f "./gradlew" ] || fail "Le wrapper Gradle (./gradlew) est manquant."

# Vérifie la version Java
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
echo "➡️  Java détecté : version $JAVA_VERSION"
[[ "$JAVA_VERSION" == 21* ]] || echo "⚠️  Attention : CAS 7.3.x requiert Java 21 (actuellement $JAVA_VERSION)."

# Vérifie la ligne casVersion dans gradle.properties
CURRENT_CAS_VERSION=$(grep '^casVersion=' $GRADLE_PROPS | cut -d'=' -f2)
echo "📦 Version CAS actuelle détectée : $CURRENT_CAS_VERSION"
echo "🎯 Nouvelle version cible : $CAS_VERSION"

# Vérifie les dépendances principales
echo "🔍 Vérification des dépendances CAS..."
grep 'implementation' build.gradle | grep 'org.apereo.cas' || echo "⚠️  Aucune dépendance CAS détectée dans build.gradle ? Vérifie ta configuration."

# Vérifie les modules ESUP
grep 'esup' build.gradle >/dev/null && echo "🧩 Modules ESUP détectés (esup-otp, agimus...)" || echo "ℹ️  Aucun module ESUP trouvé."

# Vérifie l’accès à Tomcat
systemctl status $TOMCAT_SERVICE >/dev/null 2>&1 || echo "⚠️  Le service $TOMCAT_SERVICE n’a pas été trouvé. Vérifie le nom du service Tomcat."

sleep 2

# =====================================================================
# ÉTAPE 2 : Mise à jour de la version CAS dans gradle.properties
# =====================================================================
banner "Mise à jour de la version CAS"

sed -i "s/^casVersion=.*/casVersion=$CAS_VERSION/" $GRADLE_PROPS || fail "Impossible de modifier gradle.properties"
success "Version CAS mise à jour dans gradle.properties → $CAS_VERSION"

# =====================================================================
# ÉTAPE 3 : Nettoyage et construction du projet
# =====================================================================
banner "Nettoyage et Build du projet Overlay CAS"

./gradlew clean || fail "Échec du nettoyage du projet"
./gradlew build -x test || fail "Échec de la compilation Gradle"

[ -f "$BUILD_DIR/$WAR_NAME" ] || fail "Le fichier $BUILD_DIR/$WAR_NAME n’a pas été généré."
success "Build terminé avec succès"

# =====================================================================
# ÉTAPE 4 : Archivage du WAR généré
# =====================================================================
banner "Archivage du WAR CAS"

mkdir -p "$ARCHIVE_DIR"
cp "$BUILD_DIR/$WAR_NAME" "$ARCHIVE_DIR/cas-$CAS_VERSION-$DATE.war" || fail "Impossible de copier le WAR dans $ARCHIVE_DIR"
success "Archive créée : $ARCHIVE_DIR/cas-$CAS_VERSION-$DATE.war"

# =====================================================================
# ÉTAPE 5 : Déploiement sur Tomcat
# =====================================================================
banner "Déploiement du WAR sur Tomcat"

# Stop du service Tomcat
echo "🛑 Arrêt de Tomcat ($TOMCAT_SERVICE)..."
sudo systemctl stop $TOMCAT_SERVICE || fail "Impossible d'arrêter le service Tomcat"

# Nettoyage du répertoire ROOT existant
echo "🧹 Suppression de l’ancien WAR et répertoire ROOT..."
sudo rm -rf "$CAS_DEPLOY_DIR" "$TOMCAT_WEBAPPS/ROOT.war"

# Copie du nouveau WAR
echo "📦 Déploiement du nouveau WAR CAS..."
sudo cp "$BUILD_DIR/$WAR_NAME" "$TOMCAT_WEBAPPS/ROOT.war" || fail "Erreur de copie du WAR vers $TOMCAT_WEBAPPS"

# Démarrage du service Tomcat
echo "🚀 Redémarrage de Tomcat..."
sudo systemctl start $TOMCAT_SERVICE || fail "Impossible de démarrer Tomcat"

sleep 8

# Vérifie que le service tourne
systemctl is-active --quiet $TOMCAT_SERVICE && success "Tomcat est actif et le nouveau CAS $CAS_VERSION est déployé" || fail "Tomcat ne s'est pas correctement relancé."

# =====================================================================
# ÉTAPE 6 : Validation du déploiement
# =====================================================================
banner "Validation post-déploiement"

CAS_URL="https://cas.univ-antilles.fr"
echo "🌐 Vérifie l'accès à $CAS_URL/login"
echo "🪵 Vérifie les logs sous /var/log/tomcat10/catalina.out"
echo "✅ Migration CAS $CURRENT_CAS_VERSION → $CAS_VERSION terminée avec succès."

