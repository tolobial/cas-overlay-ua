#!/bin/bash

URL="https://auth11.martinique.univ-antilles.fr/cas/login"
SERVICE="https://auth11.martinique.univ-antilles.fr/cas"
USER="pplacide"
PASS="Pabayli1+"

# Récupère la clé execution depuis la page login
execution=$(curl -sk "$URL" | grep -oP 'name="execution" value="\K[^"]+')
echo "Execution key: $execution"

# Fonction pour convertir un timestamp en date lisible
to_date() {
  if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]; then
    date -d @"$1"
  else
    echo "Session-only cookie (expires on browser close)"
  fi
}

echo
echo "---- Test sans remember-me ----"
curl -sk -L -c cookies_no.txt \
  -d "username=$USER" \
  -d "password=$PASS" \
  -d "execution=$execution" \
  -d "_eventId=submit" \
  "$URL?service=$SERVICE" > /dev/null

echo "Cookies enregistrés (sans remember-me) :"
grep TGC cookies_no.txt || echo "❌ Aucun cookie TGC trouvé"

echo
echo "---- Test avec remember-me ----"
curl -sk -L -c cookies_yes.txt \
  -d "username=$USER" \
  -d "password=$PASS" \
  -d "rememberme=true" \
  -d "execution=$execution" \
  -d "_eventId=submit" \
  "$URL?service=$SERVICE" > /dev/null

echo "Cookies enregistrés (avec remember-me) :"
grep TGC cookies_yes.txt || echo "❌ Aucun cookie TGC trouvé"

echo
echo "---- Résumé ----"

exp_no=$(grep TGC cookies_no.txt | awk '{print $5}')
exp_yes=$(grep TGC cookies_yes.txt | awk '{print $5}')

echo "Sans remember-me : $(to_date $exp_no)"
echo "Avec remember-me : $(to_date $exp_yes)"

