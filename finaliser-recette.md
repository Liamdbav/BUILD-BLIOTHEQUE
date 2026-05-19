---
description: Distille tous les brouillons de session du projet courant en une recette one-shot rejouable
argument-hint: "[nom-du-projet]"
allowed-tools: Read, Write, Edit, Bash
---

Ton rôle : produire UNE recette ultime, rejouable from scratch sans aucune erreur, pour le projet $ARGUMENTS, en agrégeant TOUS les brouillons de session disponibles.

Chaque brouillon est un résumé brut d'une session : prompts utilisateur horodatés + métadonnées. La recette distillée doit reproduire le projet final tel qu'il existe aujourd'hui, en évitant TOUTES les erreurs rencontrées dans l'historique des sessions.

ÉTAPE 0 — Détermine le nom du projet

Si $ARGUMENTS est fourni et non vide :
  NOM_AFFICHE = $ARGUMENTS (casse préservée pour le nom du fichier final)
  NOM_GLOB = $ARGUMENTS en minuscules
Sinon :
  NOM_AFFICHE = basename de $(pwd)
  NOM_GLOB = NOM_AFFICHE en minuscules

ÉTAPE 1 — Collecte TOUS les brouillons du projet

Utilise un Bash unique :

  find $VAULT/Projets -maxdepth 1 -iname ".draft-${NOM_GLOB}-*.md" -type f | sort

Lis CHAQUE fichier trouvé avec l'outil Read. Si la liste est vide, arrête et affiche : "Aucun brouillon trouvé pour ${NOM_AFFICHE} dans $VAULT/Projets/. Vérifie que le hook Stop a bien déposé des drafts."

ÉTAPE 2 — Analyse multi-sessions

Pour chaque brouillon, parcours la section "## Prompts utilisateur (brut)". Classifie chaque prompt :

STRUCTURANT : le prompt a produit un livrable persistant (fichier créé, config posée, fonctionnalité implémentée). C'est le matériau de la recette.

CORRECTIF : le prompt répond à une erreur d'un prompt précédent (même ou autre session). Ne pas inclure tel quel — fusionner avec le prompt structurant parent en intégrant la contrainte dès le départ.

EXPLORATOIRE : le prompt n'a rien produit de persistant. Éliminer.

Tiens compte des métadonnées (outils invoqués, durée) pour identifier les sessions structurantes vs exploratoires.

ÉTAPE 3 — Distillation cross-sessions

Construis UNE séquence unique de prompts parfaits, qui :
- Reproduit l'état final du projet
- Intègre toutes les contraintes apprises à travers les sessions
- Formule chaque prompt comme s'il était passé en premier, sans contexte d'erreur
- Est autonome et rejouable isolément
- A un résultat observable concret

L'ordre suit la dépendance logique du build, pas l'ordre chronologique des sessions.

ÉTAPE 4 — Écris la note finale

Cible : $VAULT/Projets/${NOM_AFFICHE}.md

Suis le format de $VAULT/_templates/recette-projet.md.

Contraintes frontmatter YAML (Obsidian) :
- tags : liste à tirets, pas inline []
- dates : format YYYY-MM-DD
- statut → stable
- stack et tags déduits du contenu des brouillons
- créé = date du brouillon le plus ancien, dernière_maj = aujourd'hui

Si le fichier existe déjà : ajoute une nouvelle itération en bas précédée d'un séparateur ---. Ne remplace JAMAIS le contenu existant.

Dans le champ "Contexte" de chaque prompt distillé : note quelle erreur réelle (rencontrée dans une des sessions) ce prompt consolidé évite.

ÉTAPE 5 — Nettoyage

Une fois la note écrite et vérifiée, supprime TOUS les brouillons du projet :

  find $VAULT/Projets -maxdepth 1 -iname ".draft-${NOM_GLOB}-*.md" -type f -delete

ÉTAPE 6 — Récap

Affiche :
- Chemin de la note finale
- Nombre de sessions analysées
- Nombre total de prompts utilisateur (tous brouillons confondus)
- Nombre de prompts dans la recette distillée
- Ratio de compression (ex : "47 → 8 prompts distillés, 83 % de compression")
