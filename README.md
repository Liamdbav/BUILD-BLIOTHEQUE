# BUILD-BLIOTHEQUE

**Claude Code Hook System & Obsidian Vault Sync**

Capture automatiquement chaque session Claude Code sous forme de brouillon, puis distille ce brouillon en recette rejouable one-shot stockée dans ton vault Obsidian.

- **Hook Stop** : génère un brouillon `.draft-*.md` dans le vault à chaque fin de session Claude Code
- **`/finaliser-recette`** : slash command qui lit le brouillon + transcript et produit une recette distillée, sans les erreurs
- **Template Obsidian** : frontmatter YAML structuré, compatible Obsidian et Dataview

---

## Flux

```
Session Claude Code (projet quelconque)
        |
        | fin de session
        v
  Hook Stop  ──────────────────────────────────────────────
        |                                                   |
        | génère automatiquement                            |
        v                                                   |
  $VAULT/Projets/.draft-<projet>-<timestamp>.md            |
        |                                                   |
        | /finaliser-recette <projet>                       |
        v                                                   |
  Analyse du transcript                                     |
  (STRUCTURANT / CORRECTIF / EXPLORATOIRE)                  |
        |                                                   |
        v                                                   |
  $VAULT/Projets/<projet>.md  <─────────────────────────────
  (recette distillée, one-shot, rejouable)
```

---

## Prérequis

| Outil | Version | Rôle |
|---|---|---|
| [Claude Code](https://claude.ai/code) | ≥ dernière | CLI — hooks + slash commands |
| bash | ≥ 3.2 | script d'installation |
| python3 | ≥ 3.8 | manipulation JSON dans le script |
| [Obsidian](https://obsidian.md) | optionnel | lecture des recettes `.md` |

---

## Installation

```bash
# Option 1 — VAULT déjà défini dans l'environnement
export VAULT="/chemin/absolu/vers/ton/vault"
chmod +x setup.sh
./setup.sh

# Option 2 — interactif (le script demande le chemin)
chmod +x setup.sh
./setup.sh
```

Le script est **idempotent** : peut être relancé sans danger. Il demande confirmation avant d'écraser un fichier existant.

> Si tu déplaces ton vault Obsidian, relance `setup.sh` — le chemin est injecté en dur dans le hook au moment de l'install.

---

## Fichiers installés

| Fichier | Emplacement | Rôle |
|---|---|---|
| `stop-draft-recette.sh` | `~/.claude/hooks/` | Hook Stop — génère les brouillons |
| `finaliser-recette.md` | `~/.claude/commands/` | Slash command `/finaliser-recette` |
| `settings.json` | `~/.claude/` | Enregistrement du hook (fusion JSON) |
| `recette-projet.md` | `$VAULT/_templates/` | Template frontmatter Obsidian |
| `Projets/` | `$VAULT/` | Répertoire des brouillons et recettes |

---

## Variable `$VAULT`

`$VAULT` est le chemin absolu de ton vault Obsidian. Pour le persister :

```bash
# Dans ~/.zshrc
export VAULT="/Users/toi/Documents/MonVault"
```

Le script peut écrire cette ligne dans `~/.zshrc` automatiquement si tu le demandes pendant l'install.

---

## Utilisation

Une fois installé, le workflow est transparent :

1. Tu travailles normalement dans Claude Code sur n'importe quel projet
2. À la fin de la session, le hook génère automatiquement un brouillon dans `$VAULT/Projets/`
3. Quand tu veux consolider : `/finaliser-recette nom-du-projet`
4. La recette distillée apparaît dans `$VAULT/Projets/nom-du-projet.md`

---

<div align="center">

Fait avec soin par **Liam** - License MIT — voir [LICENSE](LICENSE)

[![Follow on X](https://img.shields.io/badge/Follow-%40Liamdbav-000000?style=flat-square&logo=x&logoColor=white)](https://x.com/Liamdbav)

</div>
