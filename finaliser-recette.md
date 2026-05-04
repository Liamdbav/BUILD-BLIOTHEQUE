---
description: Distille le transcript de session en recette one-shot rejouable dans le Vault
argument-hint: "[nom-du-projet]"
allowed-tools: Read, Write, Edit, Bash
---

Ton rôle : produire une recette rejouable sans erreur pour le projet $ARGUMENTS.

Le transcript de session contient le build réel — avec l'exploration, les erreurs et les
corrections. Ton travail est de distiller ce bruit en une séquence minimale de prompts
parfaits, chacun one-shot, comme si le build avait été parfait du premier coup.

ÉTAPE 1 — Localise les sources

Brouillon : $VAULT/Projets/.draft-$ARGUMENTS-*.md
Si plusieurs, prends le plus récent. Si aucun, arrête et dis-le.

Le brouillon peut contenir un commentaire HTML <!-- transcript: /chemin --> — extrais ce
chemin en priorité. Sinon, cherche dans ~/.claude/transcripts/ le fichier le plus récent
correspondant à $ARGUMENTS. Si aucun transcript disponible, travaille depuis le brouillon
en le signalant.

ÉTAPE 2 — Analyse le transcript

Lis l'intégralité du transcript. Classifie chaque message utilisateur :

STRUCTURANT : le prompt a produit un livrable persistant (fichier créé, config posée,
fonctionnalité implémentée). C'est le matériau de la recette.

CORRECTIF : le prompt répond à une erreur du prompt précédent. Ne pas inclure tel quel —
fusionner avec le prompt structurant parent pour produire un prompt consolidé qui intègre
la contrainte dès le départ.

EXPLORATOIRE : le prompt n'a rien produit de persistant. Éliminer.

ÉTAPE 3 — Construis la séquence distillée

Pour chaque prompt structurant (après fusion des correctifs) :
- Réécris le prompt en intégrant toutes les contraintes apprises pendant le build
- Formule-le comme s'il était passé en premier, sans contexte d'erreur
- Vérifie qu'il est autonome et rejouable isolément
- Assigne-lui un résultat observable concret

La séquence finale doit produire le même livrable que le build réel, sans reproduire
aucune des erreurs rencontrées.

ÉTAPE 4 — Écris la note finale

Écris dans $VAULT/Projets/$ARGUMENTS.md en suivant le format de $VAULT/_templates/recette-projet.md.
Si le fichier existe déjà : ajoute une nouvelle itération en bas, ne remplace jamais le contenu existant.
Dans le champ "Contexte" de chaque prompt : note quelle erreur réelle ce prompt consolidé évite.
Frontmatter : statut → stable, stack et tags déduits du transcript, créé = date du brouillon.

ÉTAPE 5 — Finalise

Supprime $VAULT/Projets/.draft-$ARGUMENTS-*.md.

Affiche :
- Chemin de la note finale
- Nombre de prompts dans la session originale
- Nombre de prompts dans la recette distillée
- Ratio de compression (ex : "18 → 6 prompts distillés (67 %)")
