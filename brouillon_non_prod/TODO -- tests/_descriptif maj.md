En me basant sur l'audit complet (tests unitaires `core.sh`, non-régression format `.b3`, edge cases, CI GitHub Actions, tests Docker/environnement, protocole TAP, fixtures), voici la structure documentaire que je propose :

```
docs/development/testing/
│
├── index.md
│   Vue d'ensemble de la stratégie de test : pyramide, suites existantes,
│   suites à créer, liens vers chaque document.
│
├── strategy.md
│   Décision formelle : objectifs de couverture, règles de priorité,
│   définition de "done" pour un test, politique ShellCheck zéro warning.
│
├── unit-tests.md
│   Spécification de run_tests_core.sh : liste exhaustive des fonctions à
│   tester, cas nominal + cas d'erreur pour chaque fonction de core.sh,
│   mécanisme de sourcing direct, contrat d'isolation.
│
├── integration-tests.md
│   Spécification des extensions à run_tests.sh (T15-T20+) et
│   run_tests_pipeline.sh : cas manquants identifiés, oracle de chaque test,
│   comportement attendu documenté.
│
├── regression-tests.md
│   Spécification du mécanisme de non-régression format .b3 : création des
│   fixtures, procédure de mise à jour de reference.b3, règle de décision
│   (diff intentionnel vs bug).
│
├── edge-cases.md
│   Catalogue exhaustif des cas limites : noms avec espaces/newlines/
│   caractères HTML, fichiers vide, base .b3 minimale, locales, etc.
│   Pour chaque cas : input, comportement attendu, risque si non testé.
│
├── docker-tests.md
│   Spécification de run_tests_docker.sh : tests de build, tests
│   entrypoint.sh commande par commande, tests de taille d'image, tests
│   multi-plateforme amd64/arm64, prérequis Docker Buildx.
│
├── fixtures.md
│   Spécification de l'arborescence tests/fixtures/ : quels fichiers
│   créer, pourquoi chacun, procédure pour ajouter une nouvelle fixture,
│   règle de nommage.
│
├── tap-format.md
│   Spécification du format TAP à adopter : structure du header, format
│   ok/not ok, diagnostics, helpers bash à implémenter dans chaque suite,
│   compatibilité GitHub Actions.
│
└── ci-cd.md
    Spécification du workflow GitHub Actions : jobs (unit, integration,
    docker), matrice OS, conditions de déclenchement, gestion des
    artefacts, règles de blocage des PRs.
```

---

**Logique de la structure :**

- `index.md` + `strategy.md` sont les documents de décision — ils répondent à *pourquoi* et *quoi*.
- Les cinq fichiers `*-tests.md` + `edge-cases.md` sont les documents de spécification — ils répondent à *comment tester quoi exactement*.
- `fixtures.md` + `tap-format.md` sont des documents transversaux — ils décrivent des mécanismes utilisés par plusieurs suites.
- `ci-cd.md` est le document d'infrastructure — il décrit l'automatisation qui donne de la valeur à tout le reste.

Chaque fichier peut être rédigé et implémenté indépendamment, dans l'ordre de priorité de l'audit : `ci-cd.md` → `unit-tests.md` → `regression-tests.md` → `edge-cases.md` → `docker-tests.md`.