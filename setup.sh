#!/usr/bin/env bash
# BUILD-BLIOTHEQUE-install.sh
# Installe le systeme de recettes Claude Code (hook Stop + slash command /finaliser-recette).
# $VAULT est injecte en dur dans les fichiers generes -- relancer le script si le Vault change.
# Idempotent -- relancer sans risque.

set -euo pipefail

# ── Palette cyberpunk : degradé vert foret → cyan ─────────────────────────────
C0='\033[38;5;22m'
C1='\033[38;5;28m'
C2='\033[38;5;35m'
C3='\033[38;5;42m'
C4='\033[38;5;49m'
C5='\033[38;5;51m'
CY='\033[38;5;87m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${C3}  ▸${NC} ${C4}$*${NC}"; }
warn() { echo -e "${C2}  ◈${NC} ${C3}$*${NC}"; }
err()  { echo -e "${C0}  ✖${NC} ${BOLD}$*${NC}" >&2; }
info() { echo -e "${DIM}    $*${NC}"; }

h1() {
  local msg="$*"
  echo ""
  echo -e "${C1}  ╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${C2}  ║${NC} ${C3}⟦${NC} ${BOLD}${C4}${msg}${NC} ${C3}⟧${NC}"
  echo -e "${C4}  ╚══════════════════════════════════════════════════════════════╝${NC}"
}

splash() {
  local title="BUILD-BLIOTHEQUE"
  local subtitle="Claude Code  *  Hook System  *  Obsidian Vault Sync"
  local width=62
  local pad_t=$(( (width - ${#title}) / 2 ))
  local pad_s=$(( (width - ${#subtitle}) / 2 ))
  local bar=""
  local i
  for (( i=0; i<width; i++ )); do bar="${bar}="; done
  echo ""
  echo -e "${C1}  ╔${bar}╗${NC}"
  echo -e "${C2}  ║$(printf '%*s' $pad_t '')${BOLD}${C4}${title}${NC}${C2}$(printf '%*s' $(( width - pad_t - ${#title} )) '')║${NC}"
  echo -e "${C3}  ║$(printf '%*s' $pad_s '')${DIM}${subtitle}${NC}${C3}$(printf '%*s' $(( width - pad_s - ${#subtitle} )) '')║${NC}"
  echo -e "${C4}  ╚${bar}╝${NC}"
  echo -e "${C5}  ┄┄ install sequence initiated // stand by ┄┄${NC}"
  echo ""
}

splash

# ── P0 — Resolution de $VAULT ─────────────────────────────────────────────────
h1 "P0 // ENVIRONNEMENT"

if [[ -z "${VAULT:-}" ]]; then
  warn "\$VAULT non defini dans l'environnement courant."
  echo -e "${C3}  ▷${NC} ${DIM}Chemin absolu du Vault Obsidian${NC}"
  read -r -p "    > " VAULT_INPUT
  VAULT_INPUT="${VAULT_INPUT%/}"
  if [[ -z "$VAULT_INPUT" ]]; then
    err "Chemin vide. Sequence interrompue."
    exit 1
  fi
  export VAULT="$VAULT_INPUT"
  echo ""
  warn "Pour persister \$VAULT, injecte dans ~/.zshrc :"
  info "export VAULT=\"${VAULT}\""
  echo ""
  echo -e "${C3}  ▷${NC} Ecrire automatiquement dans ~/.zshrc ? ${DIM}[o/N]${NC}"
  read -r -p "    > " ADD_TO_RC
  if [[ "${ADD_TO_RC,,}" == "o" ]]; then
    echo "" >> ~/.zshrc
    echo "# Vault Obsidian - injecte par BUILD-BLIOTHEQUE-install.sh" >> ~/.zshrc
    echo "export VAULT=\"${VAULT}\"" >> ~/.zshrc
    ok "~/.zshrc mis a jour -- source ~/.zshrc pour activer"
  fi
fi

VAULT=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$VAULT")

if [[ ! -d "$VAULT" ]]; then
  warn "Repertoire introuvable : $VAULT"
  echo -e "${C3}  ▷${NC} Creer le Vault ? ${DIM}[o/N]${NC}"
  read -r -p "    > " CREATE_VAULT
  if [[ "${CREATE_VAULT,,}" == "o" ]]; then
    mkdir -p "$VAULT"
    ok "Vault initialise : $VAULT"
  else
    err "VAULT inexistant. Abandon."
    exit 1
  fi
else
  ok "\$VAULT -> ${DIM}$VAULT${NC}"
fi

if [[ ! -d "$VAULT/.obsidian" ]]; then
  warn "Aucun .obsidian detecte -- ouvre ce dossier dans Obsidian comme vault."
fi

[[ -d ~/.claude ]] || { err "~/.claude/ introuvable -- Claude Code installe ?"; exit 1; }
ok "~/.claude/ ${DIM}en ligne${NC}"

for subdir in "Projets" "_templates"; do
  TARGET="$VAULT/$subdir"
  if [[ ! -d "$TARGET" ]]; then
    mkdir -p "$TARGET"
    ok "Repertoire cree  ${DIM}-> $TARGET${NC}"
  else
    ok "Repertoire actif ${DIM}-> $TARGET${NC}"
  fi
done

# ── P1 — Template de recette ──────────────────────────────────────────────────
h1 "P1 // TEMPLATE RECETTE-PROJET"

TEMPLATE_FILE="$VAULT/_templates/recette-projet.md"

if [[ -f "$TEMPLATE_FILE" ]]; then
  warn "Template deja present -- conserve sans modification."
  info "$TEMPLATE_FILE"
else
  cat > "$TEMPLATE_FILE" << 'TMPL'
---
projet: {{projet}}
créé: {{date}}
dernière_maj: {{date}}
stack: {{stack}}
statut: draft
tags:
  - projet
  - {{techno-principale}}
---

# {{projet}}

## Intention
{{intention}}

## Stack effective
{{stack-effective}}

## Recette — Séquence de prompts

### Itération 1 — {{date}} — {{intitulé}}
**Contexte** : {{contexte}}

**Prompt** :

{{prompt}}
TMPL
  ok "Template depose ${DIM}-> $TEMPLATE_FILE${NC}"
fi

# ── P2 — Hook Stop ────────────────────────────────────────────────────────────
h1 "P2 // HOOK STOP  *  SESSION RECORDER"

HOOKS_DIR=~/.claude/hooks
mkdir -p "$HOOKS_DIR"
HOOK_FILE="$HOOKS_DIR/stop-draft-recette.sh"
SKIP_HOOK=""

if [[ -f "$HOOK_FILE" ]]; then
  warn "Hook existant detecte."
  info "$HOOK_FILE"
  echo -e "${C3}  ▷${NC} Ecraser avec la version courante ? ${DIM}[o/N]${NC}"
  read -r -p "    > " OVERWRITE_HOOK
  [[ "${OVERWRITE_HOOK,,}" != "o" ]] && { ok "Hook conserve."; SKIP_HOOK=1; }
fi

if [[ -z "$SKIP_HOOK" ]]; then
  cat > "$HOOK_FILE" << HOOK
#!/usr/bin/env bash
# Hook Stop Claude Code -- genere un brouillon de recette a chaque fin de session hors-Vault.
# Claude Code envoie un payload JSON sur stdin : cwd, session_id, transcript_path.
# VAULT hardcode a l'install : ${VAULT}

set -euo pipefail

VAULT="${VAULT}"

PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD=\$(cat 2>/dev/null || true)
fi

SESSION_CWD=""
if [[ -n "\$PAYLOAD" ]]; then
  SESSION_CWD=\$(printf '%s' "\$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd') or d.get('workspace', {}).get('project_dir', ''))
except Exception:
    pass
" 2>/dev/null || true)
fi
SESSION_CWD="\${SESSION_CWD:-\${CLAUDE_CWD:-\$(pwd)}}"
SESSION_CWD=\$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "\$SESSION_CWD" 2>/dev/null || echo "\$SESSION_CWD")

VAULT_REAL=\$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "\$VAULT" 2>/dev/null || echo "\$VAULT")
[[ "\$SESSION_CWD" == "\$VAULT_REAL"* ]] && exit 0

PROJECT_NAME=\$(basename "\$SESSION_CWD")
[[ -z "\$PROJECT_NAME" ]] && exit 0

TEMPLATE="\$VAULT/_templates/recette-projet.md"
[[ ! -f "\$TEMPLATE" ]] && { echo "[hook] Template introuvable : \$TEMPLATE" >&2; exit 0; }

DRAFT_DIR="\$VAULT/Projets"
mkdir -p "\$DRAFT_DIR"

SESSION_ID=""
TRANSCRIPT_PATH=""
if [[ -n "\$PAYLOAD" ]]; then
  SESSION_ID=\$(printf '%s' "\$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
except Exception:
    pass
" 2>/dev/null || true)
  TRANSCRIPT_PATH=\$(printf '%s' "\$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except Exception:
    pass
" 2>/dev/null || true)
fi

TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
TODAY=\$(date +%Y-%m-%d)
DRAFT_FILE="\$DRAFT_DIR/.draft-\${PROJECT_NAME}-\${TIMESTAMP}.md"

CONTEXTE="Session du \$TODAY"
[[ -n "\$SESSION_ID" ]] && CONTEXTE="\$CONTEXTE (session: \$SESSION_ID)"

sed \\
  -e "s|{{projet}}|\${PROJECT_NAME}|g" \\
  -e "s|{{date}}|\${TODAY}|g" \\
  -e "s|{{stack}}|a completer|g" \\
  -e "s|{{techno-principale}}|a completer|g" \\
  -e "s|{{intention}}|a completer|g" \\
  -e "s|{{stack-effective}}|a completer|g" \\
  -e "s|{{contexte}}|\${CONTEXTE}|g" \\
  -e "s|{{intitule}}|premiere iteration|g" \\
  -e "s|{{prompt}}|a extraire du transcript|g" \\
  "\$TEMPLATE" > "\$DRAFT_FILE"

[[ -n "\$TRANSCRIPT_PATH" ]] && printf '\n<!-- transcript: %s -->\n' "\$TRANSCRIPT_PATH" >> "\$DRAFT_FILE"

echo "[hook] Brouillon depose : \$DRAFT_FILE"
HOOK

  chmod 755 "$HOOK_FILE"
  ok "Hook injecte + chmod 755 ${DIM}-> $HOOK_FILE${NC}"
fi

# ── P3 — settings.json ────────────────────────────────────────────────────────
h1 "P3 // SETTINGS.JSON  *  HOOK REGISTRATION"

SETTINGS_PATH=~/.claude/settings.json
HOOK_COMMAND="~/.claude/hooks/stop-draft-recette.sh"
SKIP_SETTINGS=""

if [[ -f "$SETTINGS_PATH" ]]; then
  echo -e "${DIM}  ┌─ settings.json actuel ──────────────────────────────────────${NC}"
  python3 -m json.tool "$SETTINGS_PATH" 2>/dev/null | sed 's/^/    /' || cat "$SETTINGS_PATH" | sed 's/^/    /'
  echo -e "${DIM}  └────────────────────────────────────────────────────────────${NC}"
  echo ""
  echo -e "${C3}  ▷${NC} Fusionner le hook Stop dans settings.json ? ${DIM}[o/N]${NC}"
  read -r -p "    > " CONFIRM_SETTINGS
  [[ "${CONFIRM_SETTINGS,,}" != "o" ]] && { warn "settings.json non modifie."; SKIP_SETTINGS=1; }
fi

if [[ -z "$SKIP_SETTINGS" ]]; then
  python3 - << 'PYEOF'
import json, os, sys

SETTINGS_PATH = os.path.expanduser("~/.claude/settings.json")
HOOK_COMMAND = "~/.claude/hooks/stop-draft-recette.sh"
NEW_ENTRY = {"matcher": "", "hooks": [{"type": "command", "command": HOOK_COMMAND}]}

settings = {}
if os.path.exists(SETTINGS_PATH):
    with open(SETTINGS_PATH) as f:
        settings = json.load(f)

already = any(
    any(h.get("command") == HOOK_COMMAND for h in e.get("hooks", []))
    for e in settings.get("hooks", {}).get("Stop", [])
)
if already:
    print(f"  Deja enregistre : {HOOK_COMMAND}")
    sys.exit(0)

settings.setdefault("hooks", {}).setdefault("Stop", []).append(NEW_ENTRY)

tmp = SETTINGS_PATH + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, SETTINGS_PATH)
print(f"  settings.json mis a jour -> {SETTINGS_PATH}")
PYEOF
  ok "settings.json synchronise"
fi

# ── P4 — Slash command /finaliser-recette ─────────────────────────────────────
h1 "P4 // /FINALISER-RECETTE  *  SLASH COMMAND"

COMMANDS_DIR=~/.claude/commands
mkdir -p "$COMMANDS_DIR"
COMMAND_FILE="$COMMANDS_DIR/finaliser-recette.md"
SKIP_CMD=""

if [[ -f "$COMMAND_FILE" ]]; then
  warn "Slash command deja presente."
  info "$COMMAND_FILE"
  echo -e "${C3}  ▷${NC} Ecraser ? ${DIM}[o/N]${NC}"
  read -r -p "    > " OVERWRITE_CMD
  [[ "${OVERWRITE_CMD,,}" != "o" ]] && { ok "Commande conservee."; SKIP_CMD=1; }
fi

if [[ -z "$SKIP_CMD" ]]; then
  cat > "$COMMAND_FILE" << SLASHCMD
---
description: Distille le transcript de session en recette one-shot rejouable dans le Vault
argument-hint: "[nom-du-projet]"
allowed-tools: Read, Write, Edit, Bash
---

Ton role : produire une recette rejouable sans erreur pour le projet \$ARGUMENTS.

Le transcript de session contient le build reel -- avec l'exploration, les erreurs et les
corrections. Ton travail est de distiller ce bruit en une sequence minimale de prompts
parfaits, chacun one-shot, comme si le build avait ete parfait du premier coup.

ETAPE 1 -- Localise les sources

Brouillon : ${VAULT}/Projets/.draft-\$ARGUMENTS-*.md
Si plusieurs, prends le plus recent. Si aucun, arrete et dis-le.

Le brouillon peut contenir un commentaire HTML <!-- transcript: /chemin --> -- extrais ce
chemin en priorite. Sinon, cherche dans ~/.claude/transcripts/ le fichier le plus recent
correspondant a \$ARGUMENTS. Si aucun transcript disponible, travaille depuis le brouillon
en le signalant.

ETAPE 2 -- Analyse le transcript

Lis l'integralite du transcript. Classifie chaque message utilisateur :

STRUCTURANT : le prompt a produit un livrable persistant (fichier cree, config posee,
fonctionnalite implementee). C'est le materiau de la recette.

CORRECTIF : le prompt repond a une erreur du prompt precedent. Ne pas inclure tel quel --
fusionner avec le prompt structurant parent pour produire un prompt consolide qui integre
la contrainte des le depart.

EXPLORATOIRE : le prompt n'a rien produit de persistant. Eliminer.

ETAPE 3 -- Construis la sequence distillee

Pour chaque prompt structurant (apres fusion des correctifs) :
- Reecris le prompt en integrant toutes les contraintes apprises pendant le build
- Formule-le comme s'il etait passe en premier, sans contexte d'erreur
- Verifie qu'il est autonome et rejouable isolement
- Assigne-lui un resultat observable concret

La sequence finale doit produire le meme livrable que le build reel, sans reproduire
aucune des erreurs rencontrees.

ETAPE 4 -- Ecris la note finale

Ecris dans ${VAULT}/Projets/\$ARGUMENTS.md en suivant le format de ${VAULT}/_templates/recette-projet.md.

Contraintes frontmatter YAML (Obsidian) :
- tags : liste a tirets, pas inline []
- dates : format YYYY-MM-DD
- statut -> stable
- stack et tags deduits du transcript
- cree = date du brouillon, derniere_maj = date du jour

Si le fichier existe deja : ajoute une nouvelle iteration en bas precedee d'un separateur ---.
Ne remplace jamais le contenu existant.
Dans le champ "Contexte" de chaque prompt : note quelle erreur reelle ce prompt consolide evite.

ETAPE 5 -- Finalise

Supprime ${VAULT}/Projets/.draft-\$ARGUMENTS-*.md.

Affiche :
- Chemin de la note finale
- Nombre de prompts dans la session originale
- Nombre de prompts dans la recette distillee
- Ratio de compression (ex : "18 -> 6 prompts distilles (67 %)")
SLASHCMD

  ok "Slash command deposee ${DIM}-> $COMMAND_FILE${NC}"
fi

# ── P5 — Test bout en bout ────────────────────────────────────────────────────
h1 "P5 // DIAGNOSTIC  *  END-TO-END TEST"

echo -e "${C3}  ▷${NC} Lancer le test de bout en bout ? ${DIM}[o/N]${NC}"
read -r -p "    > " RUN_TEST

if [[ "${RUN_TEST,,}" == "o" ]]; then

  TEST_DIR=/tmp/TEST-RECETTE-INSTALL
  mkdir -p "$TEST_DIR"

  echo ""
  info "Injection payload JSON -- simulation Claude Code Stop event..."
  HOOK_OUTPUT=$(printf '{"cwd":"%s","session_id":"test-install-001","transcript_path":""}' "$TEST_DIR" \
    | VAULT="$VAULT" "$HOOK_FILE" 2>&1 || true)
  echo -e "${C3}  ◎${NC} ${DIM}$HOOK_OUTPUT${NC}"

  DRAFT=$(ls "$VAULT/Projets/.draft-TEST-RECETTE-INSTALL-"*.md 2>/dev/null | sort | tail -1 || true)

  if [[ -z "$DRAFT" ]]; then
    err "Brouillon non trouve -- hook defaillant."
  else
    ok "Brouillon genere ${DIM}-> $DRAFT${NC}"

    COUNT=$(python3 -c "
import re, sys
content = open(sys.argv[1]).read()
print(len(re.findall(r'\{\{[a-z-]+\}\}', content)))
" "$DRAFT")
    [[ "$COUNT" == "0" ]] \
      && ok "Placeholders residuels ${DIM}-> 0${NC}" \
      || warn "$COUNT placeholder(s) residuel(s)"

    OBSIDIAN_CHECK=$(python3 -c "
import sys
content = open(sys.argv[1]).read()
if content.startswith('---'):
    end = content.index('---', 3)
    fm = content[3:end]
    print('WARN' if 'tags: [' in fm else 'OK')
else:
    print('WARN')
" "$DRAFT")
    [[ "$OBSIDIAN_CHECK" == "OK" ]] \
      && ok "Frontmatter YAML ${DIM}-> compatible Obsidian${NC}" \
      || warn "Tags inline [] detectes -- verifier le template"

    echo ""
    echo -e "${DIM}  ┌─ contenu brouillon ─────────────────────────────────────────${NC}"
    cat "$DRAFT" | sed 's/^/    /'
    echo -e "${DIM}  └─────────────────────────────────────────────────────────────${NC}"

    rm -f "$DRAFT"
    rmdir "$TEST_DIR" 2>/dev/null || true
    ok "Nettoyage effectue"
  fi
else
  warn "Test ignore."
fi

# ── Recap final ───────────────────────────────────────────────────────────────
echo ""
echo -e "${C1}  ╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${C2}  ║  BUILD-BLIOTHEQUE -- installation complete                ║${NC}"
echo -e "${C4}  ╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${C3}  VAULT     ${NC}${DIM}$VAULT${NC}"
echo -e "${C3}  TEMPLATE  ${NC}${DIM}$VAULT/_templates/recette-projet.md${NC}"
echo -e "${C3}  HOOK      ${NC}${DIM}~/.claude/hooks/stop-draft-recette.sh${NC}"
echo -e "${C3}  SETTINGS  ${NC}${DIM}~/.claude/settings.json${NC}"
echo -e "${C3}  SLASH CMD ${NC}${DIM}~/.claude/commands/finaliser-recette.md${NC}"
echo ""
echo -e "${DIM}  $VAULT/${NC}"
echo -e "${DIM}  +-- .obsidian/${NC}"
echo -e "${DIM}  +-- _templates/recette-projet.md${NC}"
echo -e "${DIM}  +-- Projets/.draft-*       <- brouillons auto (caches Obsidian)${NC}"
echo -e "${DIM}  +-- Projets/NOM-PROJET.md  <- notes finales${NC}"
echo ""
echo -e "${C4}  ▸ hook${NC}   ${DIM}fin de session Claude Code hors-Vault -> brouillon auto${NC}"
echo -e "${C4}  ▸ cmd${NC}    ${DIM}/finaliser-recette <nom-projet> dans Claude Code${NC}"
echo ""
echo -e "${C2}  ⚠${NC}  ${DIM}Vault deplace ? Relancer ce script.${NC}"
echo ""
echo -e "${C5}  // system ready //${NC}"
echo ""
