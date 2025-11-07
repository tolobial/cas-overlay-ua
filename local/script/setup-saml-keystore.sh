#!/bin/bash
#
# Génération des keystores SAML2 (signing + encryption) pour Apereo CAS
# Université des Antilles - Domaine *.martinique.univ-antilles.fr
#

set -euo pipefail

# ===============================
# Variables
# ===============================
CERT=/etc/cas/saml/wildcard.crt
KEY=/etc/cas/saml/wildcard.key
STOREPASS="changeit"

SIGNING=/etc/cas/saml/idp-signing.p12
ENCRYPTION=/etc/cas/saml/idp-encryption.p12

# ===============================
# Vérifications
# ===============================
if [[ ! -f "$CERT" ]]; then
  echo "❌ Certificat introuvable : $CERT"
  exit 1
fi

if [[ ! -f "$KEY" ]]; then
  echo "❌ Clé privée introuvable : $KEY"
  exit 1
fi

mkdir -p /etc/cas/saml

# ===============================
# Génération du keystore Signing
# ===============================
echo "🔑 Génération du keystore Signing..."
openssl pkcs12 -export \
  -in "$CERT" \
  -inkey "$KEY" \
  -name idp \
  -out "$SIGNING" \
  -password pass:"$STOREPASS"

# ===============================
# Génération du keystore Encryption
# ===============================
echo "🔑 Génération du keystore Encryption..."
openssl pkcs12 -export \
  -in "$CERT" \
  -inkey "$KEY" \
  -name idp \
  -out "$ENCRYPTION" \
  -password pass:"$STOREPASS"

# ===============================
# Vérification des keystores
# ===============================
echo "✅ Vérification du keystore Signing..."
keytool -list -v -keystore "$SIGNING" -storetype PKCS12 -storepass "$STOREPASS" | grep "Alias name"

echo "✅ Vérification du keystore Encryption..."
keytool -list -v -keystore "$ENCRYPTION" -storetype PKCS12 -storepass "$STOREPASS" | grep "Alias name"

echo "🎉 Keystores générés avec succès !"
echo "➡️  Signing:     $SIGNING"
echo "➡️  Encryption:  $ENCRYPTION"
echo "⚠️  Mot de passe: $STOREPASS"

