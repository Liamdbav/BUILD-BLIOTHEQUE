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
  if [[ "$(echo "$ADD_TO_RC" | tr '[:upper:]' '[:lower:]')" == "o" ]]; then
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
  if [[ "$(echo "$CREATE_VAULT" | tr '[:upper:]' '[:lower:]')" == "o" ]]; then
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
  [[ "$(echo "$OVERWRITE_HOOK" | tr '[:upper:]' '[:lower:]')" != "o" ]] && { ok "Hook conserve."; SKIP_HOOK=1; }
fi

if [[ -z "$SKIP_HOOK" ]]; then
  cat > "$HOOK_FILE" << HOOK
#!/usr/bin/env bash
# Hook Stop Claude Code -- maintient un brouillon de recette par session, hors-Vault.
# Payload JSON sur stdin : cwd, session_id, transcript_path.
# Idempotent : a chaque Stop d'une meme session, le draft est reecrit avec le transcript a jour.
# VAULT hardcode a l'install : ${VAULT}

set -euo pipefail

VAULT="${VAULT}"

PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD=\$(cat 2>/dev/null || true)
fi

# Parse payload (cwd, session_id, transcript_path) en un seul appel Python
PARSED=\$(printf '%s' "\$PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    cwd = d.get('cwd') or d.get('workspace', {}).get('project_dir', '') or ''
    sid = d.get('session_id', '') or ''
    tpath = d.get('transcript_path', '') or ''
    print(cwd)
    print(sid)
    print(tpath)
except Exception:
    print(''); print(''); print('')
" 2>/dev/null || printf '\n\n\n')

SESSION_CWD=\$(printf '%s\n' "\$PARSED" | sed -n '1p')
SESSION_ID=\$(printf '%s\n' "\$PARSED" | sed -n '2p')
TRANSCRIPT_PATH=\$(printf '%s\n' "\$PARSED" | sed -n '3p')

SESSION_CWD="\${SESSION_CWD:-\${CLAUDE_CWD:-\$(pwd)}}"
SESSION_CWD=\$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "\$SESSION_CWD" 2>/dev/null || echo "\$SESSION_CWD")

VAULT_REAL=\$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "\$VAULT" 2>/dev/null || echo "\$VAULT")
[[ "\$SESSION_CWD" == "\$VAULT_REAL"* ]] && exit 0

PROJECT_RAW=\$(basename "\$SESSION_CWD")
[[ -z "\$PROJECT_RAW" ]] && exit 0
PROJECT_NAME=\$(printf '%s' "\$PROJECT_RAW" | tr '[:upper:]' '[:lower:]')

TEMPLATE="\$VAULT/_templates/recette-projet.md"
[[ ! -f "\$TEMPLATE" ]] && { echo "[hook] Template introuvable : \$TEMPLATE" >&2; exit 0; }

DRAFT_DIR="\$VAULT/Projets"
mkdir -p "\$DRAFT_DIR"

# Identifiant court de session pour deduplication
SESSION_ID_SHORT="\${SESSION_ID:0:8}"
[[ -z "\$SESSION_ID_SHORT" ]] && SESSION_ID_SHORT="nosess\$\$"

# Si un draft de cette session existe deja, on reutilise son nom (preserve la date de creation)
EXISTING=\$(ls -1 "\$DRAFT_DIR"/.draft-"\${PROJECT_NAME}"-*-"\${SESSION_ID_SHORT}".md 2>/dev/null | head -1 || true)

if [[ -n "\$EXISTING" ]]; then
  DRAFT_FILE="\$EXISTING"
  # Recupere la date d'origine encodee dans le nom (format YYYYMMDD-HHMMSS)
  CREATED_DATE=\$(basename "\$EXISTING" | sed -n "s|^\.draft-\${PROJECT_NAME}-\\([0-9]\\{8\\}-[0-9]\\{6\\}\\)-.*|\\1|p")
else
  CREATED_DATE=\$(date +%Y%m%d-%H%M%S)
  DRAFT_FILE="\$DRAFT_DIR/.draft-\${PROJECT_NAME}-\${CREATED_DATE}-\${SESSION_ID_SHORT}.md"
fi

TODAY=\$(date +%Y-%m-%d)
NOW_HUMAN=\$(date '+%Y-%m-%d %H:%M:%S')
CREATED_HUMAN=\$(printf '%s' "\$CREATED_DATE" | python3 -c "
import sys
s = sys.stdin.read().strip()
if len(s) >= 15:
    print(f'{s[0:4]}-{s[4:6]}-{s[6:8]} {s[9:11]}:{s[11:13]}:{s[13:15]}')
else:
    print(s)
")
CREATED_YMD=\$(printf '%s' "\$CREATED_DATE" | cut -c1-8 | python3 -c "
import sys
s = sys.stdin.read().strip()
print(f'{s[0:4]}-{s[4:6]}-{s[6:8]}' if len(s) >= 8 else s)
")

# ── Extraction du transcript ──────────────────────────────────────────────────
TRANSCRIPT_BLOCK=""
if [[ -n "\$TRANSCRIPT_PATH" && -f "\$TRANSCRIPT_PATH" ]]; then
  TRANSCRIPT_BLOCK=\$(python3 - "\$TRANSCRIPT_PATH" << 'PYTRANS'
import sys, json, datetime

path = sys.argv[1]
prompts = []        # liste de (timestamp, text)
tools = {}          # nom outil -> count
n_user = 0
n_assistant = 0
first_ts = None
last_ts = None

def parse_ts(s):
    if not s:
        return None
    try:
        return datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
    except Exception:
        return None

def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for blk in content:
            if isinstance(blk, dict):
                if blk.get('type') == 'text' and blk.get('text'):
                    parts.append(blk['text'])
                elif blk.get('type') == 'tool_use':
                    tools[blk.get('name', 'unknown')] = tools.get(blk.get('name', 'unknown'), 0) + 1
        return '\n'.join(parts).strip()
    return ''

try:
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            ts = parse_ts(ev.get('timestamp'))
            if ts:
                if first_ts is None or ts < first_ts:
                    first_ts = ts
                if last_ts is None or ts > last_ts:
                    last_ts = ts
            etype = ev.get('type')
            msg = ev.get('message') or {}
            role = msg.get('role') or etype
            if role == 'user' and etype == 'user':
                txt = extract_text(msg.get('content', ev.get('content', '')))
                # Filtre les tool_result et messages systeme injectes
                if txt and not txt.startswith('<') and 'tool_use_id' not in str(msg.get('content', '')):
                    n_user += 1
                    ts_str = ts.strftime('%H:%M:%S') if ts else '--:--:--'
                    if len(txt) > 2000:
                        txt = txt[:2000] + '… [tronque]'
                    prompts.append((ts_str, txt))
            elif role == 'assistant' and etype == 'assistant':
                n_assistant += 1
                extract_text(msg.get('content', []))  # collecte les outils
except FileNotFoundError:
    print('TRANSCRIPT_INTROUVABLE')
    sys.exit(0)

duration = ''
if first_ts and last_ts:
    delta = last_ts - first_ts
    total = int(delta.total_seconds())
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    duration = f'{h}h{m:02d}m' if h else f'{m}m{s:02d}s'

print('## Metadonnees session')
print('')
print(f'- Tours utilisateur : {n_user}')
print(f'- Tours assistant : {n_assistant}')
print('- Duree : ' + (duration or 'inconnue'))
if tools:
    tl = ', '.join(f'{k} ({v})' for k, v in sorted(tools.items(), key=lambda x: -x[1]))
    print(f'- Outils invoques : {tl}')
print('')
print('## Prompts utilisateur (brut)')
print('')
if not prompts:
    print('_aucun prompt utilisateur extrait_')
else:
    for i, (ts, txt) in enumerate(prompts, 1):
        print(f'### Prompt {i} — {ts}')
        print('')
        print(txt)
        print('')
PYTRANS
)
fi

# ── Generation du draft ───────────────────────────────────────────────────────
{
  echo '---'
  echo "projet: \${PROJECT_NAME}"
  echo "créé: \${CREATED_YMD}"
  echo "dernière_maj: \${TODAY}"
  echo "session_id: \${SESSION_ID}"
  echo "stack: a completer"
  echo "statut: draft"
  echo "tags:"
  echo "  - projet"
  echo "  - brouillon"
  echo '---'
  echo ''
  echo "# \${PROJECT_NAME} — brouillon de session"
  echo ''
  echo "Session initiee le \${CREATED_HUMAN}, derniere mise a jour \${NOW_HUMAN}."
  echo ''
  if [[ -n "\$TRANSCRIPT_BLOCK" ]]; then
    printf '%s\n' "\$TRANSCRIPT_BLOCK"
  else
    echo '## Metadonnees session'
    echo ''
    echo '_transcript_path absent ou illisible_'
    echo ''
    echo '## Prompts utilisateur (brut)'
    echo ''
    echo '_indisponible_'
    echo ''
  fi
  [[ -n "\$TRANSCRIPT_PATH" ]] && printf '<!-- transcript: %s -->\n' "\$TRANSCRIPT_PATH"
} > "\$DRAFT_FILE.tmp"
mv "\$DRAFT_FILE.tmp" "\$DRAFT_FILE"

echo "[hook] Brouillon a jour : \$DRAFT_FILE"
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
  [[ "$(echo "$CONFIRM_SETTINGS" | tr '[:upper:]' '[:lower:]')" != "o" ]] && { warn "settings.json non modifie."; SKIP_SETTINGS=1; }
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
  [[ "$(echo "$OVERWRITE_CMD" | tr '[:upper:]' '[:lower:]')" != "o" ]] && { ok "Commande conservee."; SKIP_CMD=1; }
fi

if [[ -z "$SKIP_CMD" ]]; then
  cat > "$COMMAND_FILE" << SLASHCMD
---
description: Distille tous les brouillons de session du projet courant en une recette one-shot rejouable
argument-hint: "[nom-du-projet]"
allowed-tools: Read, Write, Edit, Bash
---

Ton role : produire UNE recette ultime, rejouable from scratch sans aucune erreur, pour le projet \$ARGUMENTS, en agregeant TOUS les brouillons de session disponibles.

Chaque brouillon est un resume brut d'une session : prompts utilisateur horodate + metadonnees. La recette distillee doit reproduire le projet final tel qu'il existe aujourd'hui, en evitant TOUTES les erreurs rencontrees dans l'historique des sessions.

ETAPE 0 -- Determine le nom du projet

Si \$ARGUMENTS est fourni et non vide :
  NOM_AFFICHE = \$ARGUMENTS (casse preservee pour le nom du fichier final)
  NOM_GLOB = \$ARGUMENTS en minuscules
Sinon :
  NOM_AFFICHE = basename de \$(pwd)
  NOM_GLOB = NOM_AFFICHE en minuscules

ETAPE 1 -- Collecte TOUS les brouillons du projet

Utilise un Bash unique :

  find ${VAULT}/Projets -maxdepth 1 -iname ".draft-\${NOM_GLOB}-*.md" -type f | sort

Lis CHAQUE fichier trouve avec l'outil Read. Si la liste est vide, arrete et affiche : "Aucun brouillon trouve pour \${NOM_AFFICHE} dans ${VAULT}/Projets/. Verifie que le hook Stop a bien depose des drafts."

ETAPE 2 -- Analyse multi-sessions

Pour chaque brouillon, parcours la section "## Prompts utilisateur (brut)". Classifie chaque prompt :

STRUCTURANT : le prompt a produit un livrable persistant (fichier cree, config posee, fonctionnalite implementee). C'est le materiau de la recette.

CORRECTIF : le prompt repond a une erreur d'un prompt precedent (meme ou autre session). Ne pas inclure tel quel -- fusionner avec le prompt structurant parent en integrant la contrainte des le depart.

EXPLORATOIRE : le prompt n'a rien produit de persistant. Eliminer.

Tiens compte des metadonnees (outils invoques, duree) pour identifier les sessions structurantes vs exploratoires.

ETAPE 3 -- Distillation cross-sessions

Construis UNE sequence unique de prompts parfaits, qui :
- Reproduit l'etat final du projet
- Integre toutes les contraintes apprises a travers les sessions
- Formule chaque prompt comme s'il etait passe en premier, sans contexte d'erreur
- Est autonome et rejouable isolement
- A un resultat observable concret

L'ordre suit la dependance logique du build, pas l'ordre chronologique des sessions.

ETAPE 4 -- Ecris la note finale

Cible : ${VAULT}/Projets/\${NOM_AFFICHE}.md

Suis le format de ${VAULT}/_templates/recette-projet.md.

Contraintes frontmatter YAML (Obsidian) :
- tags : liste a tirets, pas inline []
- dates : format YYYY-MM-DD
- statut -> stable
- stack et tags deduits du contenu des brouillons
- cree = date du brouillon le plus ancien, derniere_maj = aujourd'hui

Si le fichier existe deja : ajoute une nouvelle iteration en bas precedee d'un separateur ---. Ne remplace JAMAIS le contenu existant.

Dans le champ "Contexte" de chaque prompt distille : note quelle erreur reelle (rencontree dans une des sessions) ce prompt consolide evite.

ETAPE 5 -- Nettoyage

Une fois la note ecrite et verifiee, supprime TOUS les brouillons du projet :

  find ${VAULT}/Projets -maxdepth 1 -iname ".draft-\${NOM_GLOB}-*.md" -type f -delete

ETAPE 6 -- Recap

Affiche :
- Chemin de la note finale
- Nombre de sessions analysees
- Nombre total de prompts utilisateur (tous brouillons confondus)
- Nombre de prompts dans la recette distillee
- Ratio de compression (ex : "47 -> 8 prompts distilles, 83 % de compression")
SLASHCMD

  ok "Slash command deposee ${DIM}-> $COMMAND_FILE${NC}"
fi

# ── P5 — Test bout en bout ────────────────────────────────────────────────────
h1 "P5 // DIAGNOSTIC  *  END-TO-END TEST"

echo -e "${C3}  ▷${NC} Lancer le test de bout en bout ? ${DIM}[o/N]${NC}"
read -r -p "    > " RUN_TEST

if [[ "$(echo "$RUN_TEST" | tr '[:upper:]' '[:lower:]')" == "o" ]]; then

  TEST_DIR=/tmp/TEST-RECETTE-INSTALL
  mkdir -p "$TEST_DIR"
  TEST_TRANSCRIPT=/tmp/test-recette-transcript.jsonl
  TEST_SESSION_ID="abc12345-test-fake-session-id-0000000000"
  TEST_SESSION_SHORT="abc12345"

  # Faux transcript .jsonl avec 2 prompts user + 1 tour assistant + 1 outil
  cat > "$TEST_TRANSCRIPT" << 'JSONL'
{"type":"user","timestamp":"2026-05-19T10:00:00Z","message":{"role":"user","content":"premier prompt de test"}}
{"type":"assistant","timestamp":"2026-05-19T10:00:05Z","message":{"role":"assistant","content":[{"type":"text","text":"ok"},{"type":"tool_use","name":"Bash","input":{}}]}}
{"type":"user","timestamp":"2026-05-19T10:01:00Z","message":{"role":"user","content":"second prompt apres correction"}}
{"type":"assistant","timestamp":"2026-05-19T10:01:10Z","message":{"role":"assistant","content":[{"type":"text","text":"fait"}]}}
JSONL

  echo ""
  info "Injection #1 -- premier Stop event de la session $TEST_SESSION_SHORT..."
  HOOK_OUT1=$(printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$TEST_DIR" "$TEST_SESSION_ID" "$TEST_TRANSCRIPT" \
    | "$HOOK_FILE" 2>&1 || true)
  echo -e "${C3}  ◎${NC} ${DIM}$HOOK_OUT1${NC}"

  info "Injection #2 -- second Stop event de la MEME session (test idempotence)..."
  HOOK_OUT2=$(printf '{"cwd":"%s","session_id":"%s","transcript_path":"%s"}' "$TEST_DIR" "$TEST_SESSION_ID" "$TEST_TRANSCRIPT" \
    | "$HOOK_FILE" 2>&1 || true)
  echo -e "${C3}  ◎${NC} ${DIM}$HOOK_OUT2${NC}"

  # Le projet est "test-recette-install" (basename minuscule)
  DRAFTS=( $(ls "$VAULT/Projets/.draft-test-recette-install-"*-"${TEST_SESSION_SHORT}".md 2>/dev/null) )
  N_DRAFTS=${#DRAFTS[@]}

  if [[ "$N_DRAFTS" -eq 0 ]]; then
    err "Aucun brouillon trouve -- hook defaillant."
  elif [[ "$N_DRAFTS" -gt 1 ]]; then
    err "Idempotence cassee : $N_DRAFTS brouillons pour une seule session."
    printf '    %s\n' "${DRAFTS[@]}"
  else
    DRAFT="${DRAFTS[0]}"
    ok "Brouillon unique ${DIM}-> $DRAFT${NC}"
    ok "Idempotence par session_id ${DIM}-> OK (2 Stop -> 1 fichier)${NC}"

    # Verifie la presence des sections cles
    if grep -q '^## Metadonnees session' "$DRAFT" && grep -q '^## Prompts utilisateur' "$DRAFT"; then
      ok "Sections resume + metadonnees ${DIM}-> presentes${NC}"
    else
      warn "Sections attendues manquantes dans le draft"
    fi

    if grep -q 'premier prompt de test' "$DRAFT" && grep -q 'second prompt apres correction' "$DRAFT"; then
      ok "Prompts utilisateur extraits ${DIM}-> 2/2${NC}"
    else
      warn "Extraction des prompts utilisateur incomplete"
    fi

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
    sed 's/^/    /' "$DRAFT"
    echo -e "${DIM}  └─────────────────────────────────────────────────────────────${NC}"

    rm -f "$DRAFT"
    ok "Nettoyage effectue"
  fi

  rm -f "$TEST_TRANSCRIPT"
  rmdir "$TEST_DIR" 2>/dev/null || true
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
