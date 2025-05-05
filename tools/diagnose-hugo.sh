#!/bin/bash

VERBOSE=0
[[ "$1" == "--verbose" ]] && VERBOSE=1

# Helper: section display
section() {
  echo ""
  echo "🔹 $1"
}

# Helper: result with emoji
result() {
  if [ $1 -eq 0 ]; then
    echo "✅ $2"
  else
    echo "❌ $3"
  fi
}

# Détection de Python 3.11+ avec tomllib
detect_python() {
  if command -v python3 >/dev/null; then
    PYTHON="python3"
  elif command -v python >/dev/null; then
    PYTHON="python"
  else
    PYTHON=""
  fi
}

# Result flag
FAILURES=0

### 1. Hugo version + extended
section "1. Hugo"
HUGO_VERSION=$(hugo version 2>/dev/null)
echo "$HUGO_VERSION" | grep -q "extended"
if [ $? -eq 0 ]; then
  result 0 "Hugo extended détecté"
else
  result 1 "" "Hugo n'est pas la version extended ou pas installé"
  FAILURES=$((FAILURES+1))
fi
[ $VERBOSE -eq 1 ] && echo "$HUGO_VERSION"

### 2. Git version + repo check
section "2. Git"
git --version || { echo "❌ Git non installé"; FAILURES=$((FAILURES+1)); }
git rev-parse --is-inside-work-tree >/dev/null 2>&1
result $? "Dépôt Git détecté" "⚠️ Pas dans un dépôt Git (ou repo corrompu)"

### 3. Remote Git
section "3. Remote Git"
git remote -v || echo "⚠️ Aucun remote configuré"

### 4. Sous-module PaperMod
section "4. PaperMod (sous-module)"
[ -d themes/PaperMod ] && result 0 "themes/PaperMod trouvé" || { result 1 "" "Sous-module PaperMod absent"; FAILURES=$((FAILURES+1)); }
[ $VERBOSE -eq 1 ] && git submodule status

### 5. Dossiers essentiels
section "5. Dossiers standards"
for dir in archetypes content themes .github .github/workflows; do
  [ -d "$dir" ] && echo "✅ $dir" || { echo "❌ $dir absent"; FAILURES=$((FAILURES+1)); }
done

### 6. Fichier de déploiement
section "6. Fichier deploy.yml"
[ -f .github/workflows/deploy.yml ] && result 0 "deploy.yml trouvé" || { result 1 "" "deploy.yml manquant"; FAILURES=$((FAILURES+1)); }

### 7. Fichier CNAME
section "7. Domaine personnalisé (CNAME)"
[ -f static/CNAME ] && result 0 "CNAME présent dans static/" || echo "⚠️ Pas de CNAME (normal si domaine pas encore relié)"

### 8. Pagination dans config.toml
section "8. Pagination dans config.toml"
detect_python
if [ -n "$PYTHON" ]; then
  $PYTHON -c '
import tomllib
with open("config.toml", "rb") as f:
    data = tomllib.load(f)
    pg = data.get("pagination", {})
    if "pagerSize" in pg:
        print("✅ pagination.pagerSize détecté :", pg["pagerSize"])
    else:
        print("❌ pagination.pagerSize manquant dans [pagination]")
' || { echo "❌ Erreur lecture config.toml (TOML invalide ?)"; FAILURES=$((FAILURES+1)); }
else
  echo "⚠️ Aucun interpréteur Python 3.11+ détecté. Analyse pagination ignorée."
fi

### 9. Syntaxe TOML
section "9. Validation syntaxique config.toml"
if [ -n "$PYTHON" ]; then
  $PYTHON -c 'import tomllib; tomllib.load(open("config.toml", "rb"))' 2>/dev/null
  result $? "config.toml : syntaxe valide (TOML v1.0)" "config.toml invalide (erreur TOML)"
else
  echo "⚠️ Python 3.11+ manquant : validation TOML sautée"
fi

### 10. Fichiers archetypes attendus
section "10. Archetypes attendus"
for file in post.md page.md event.md resource.md; do
  [ -f "archetypes/$file" ] && echo "✅ archetypes/$file" || { echo "❌ archetypes/$file manquant"; FAILURES=$((FAILURES+1)); }
done

### 11. Git status (verbose)
if [ $VERBOSE -eq 1 ]; then
  section "11. État du dépôt"
  git status
fi

### Résumé
section "🧾 Résumé"
if [ $FAILURES -eq 0 ]; then
  echo "🎉 Tous les points critiques sont validés. Configuration propre."
else
  echo "⚠️ $FAILURES erreur(s) détectée(s). Corriger avant déploiement."
fi
echo "📌 Utilise ./tools/diagnose-hugo.sh --verbose pour plus de détails"