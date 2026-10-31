# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

# Économie de tokens (s'applique à toutes les sessions)
Mon budget de tokens est limité. Autorisation permanente d'utiliser des sous-agents, et c'est même le fonctionnement attendu :
- **Le modèle principal orchestre** : il fait le plan, prend les décisions, pose les questions et vérifie le résultat final. Il ne fait pas lui-même le travail qui demande peu d'expertise.
- **Déléguer par défaut à des sous-agents `haiku`** : recherche web, lecture ou extraction de gros documents (PDF, pages web, logs), exploration de fichiers, tâches mécaniques, premiers brouillons. Utiliser **`sonnet`** seulement quand la tâche demande plus de fiabilité ou de raisonnement (extraction qui doit être exacte, rédaction soignée, code non trivial).
- **Lancer en parallèle** les sous-agents indépendants.
- **Rapports locaux** : chaque sous-agent écrit ses résultats dans un fichier markdown du projet (ex. `rapports/NN-sujet.md`) et ne renvoie qu'un résumé court. Le modèle principal lit ces rapports plutôt que les sources brutes.
- **Me dire quand compacter** : à la fin d'une phase, quand l'essentiel est dans les rapports, me proposer de lancer `/compact`.

# Machines virtuelles
Éviter d'utiliser des VM (Cowork, exécution de code dans une VM, sandbox virtualisée du Claude desktop, Docker/Lima/UTM, etc.) : elles prennent ~10 Go de disque. Ne jamais en lancer sans me le demander explicitement, et seulement quand c'est vraiment nécessaire ou nettement bénéfique.
