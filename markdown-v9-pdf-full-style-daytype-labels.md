# ROLE

Tu es un agent spécialisé en python, flutter et BDD.

## OBJECTIF

Documenter et figer l’évolution des exports PDF autour de 2 points :

1. **Harmoniser l’export PDF complet d’une date** avec le même style visuel que l’export roadmap.
2. **Remplacer l’affichage technique des `DayType`** par des libellés métier lisibles :
   - `concert`
   - `day off`

## CONTEXTE

- Backend : FastAPI + SQLModel + ReportLab
- Fichier principal concerné : `backend/app/services/pdf_export.py`
- Export roadmap déjà stylé (header, carte infos, tableau planning, pagination)
- Besoin utilisateur : même rendu premium pour l’export complet + labels de type lisibles

## CHANGEMENTS APPLIQUÉS

### 1) Export complet redesigné (même style que roadmap)

`build_day_full_pdf(...)` a été refondu avec :

- Header sombre avec accent orange
- Titre centré, cohérent avec roadmap
- Carte d’informations structurée
- Bloc de suivi (checkbox visuelles)
- Blocs texte stylés : Contact, Finance, Hébergement, Note
- Tableau planning stylé avec alternance des lignes
- Pagination propre avec reconstruction du layout en nouvelle page

### 2) DayType rendu lisible

Un mapping métier dédié a été ajouté :

- `concert` -> `concert`
- `day_off` -> `day off`

Application du mapping dans :

- carte infos de l’export complet (ligne Type)
- export tournée (liste des dates)
- logique conditionnelle de rendu tracking dans l’export complet

## RÈGLES MÉTIER

- Le PDF complet inclut **toutes** les informations de la date + tous les schedules.
- Le style visuel de l’export complet doit rester aligné avec roadmap.
- Les libellés de type affichés dans les PDF ne doivent jamais exposer des valeurs techniques (`DayType.xxx`, `day_off`).

## CAS LIMITES

- Si un type inconnu est rencontré, fallback de sécurité vers `concert`.
- Si des champs sont vides (city, venue, address, notes), le PDF garde un placeholder lisible (`-`).
- En pagination, les sections clés sont reconstruites avant reprise du tableau planning.

## COMPORTEMENTS ATTENDUS

- L’export complet a une présentation premium homogène avec roadmap.
- L’utilisateur lit toujours les types sous forme : `concert` / `day off`.
- Aucune régression backend (compilation OK après modification).

## VALIDATION

- Vérification effectuée : compilation backend
- Commande exécutée : `python -m compileall app`
- Résultat : OK
