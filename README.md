# dbt_client_project : Medallion Architecture sur Snowflake (Tasty Bytes)

Projet dbt d'apprentissage qui transforme la table `RAW_CUSTOMER.CUSTOMER_LOYALTY`
de la base **FROSTBYTE_TASTY_BYTES** en trois couches : **Bronze → Silver → Gold**.

```
CUSTOMER_LOYALTY ──► bronze_client (VIEW) ──► silver_client (TABLE) ──► gold_client (TABLE)
                                                                 ▲
                                    ORDER_HEADER + ORDER_DETAIL ─┘
```

---

## 📁 Structure

```
dbt_client_project/
├── dbt_project.yml            # Config du projet : nom, matérialisations par couche
├── profiles.yml               # Connexion Snowflake (secrets via variables d'env)
├── requirements.txt           # Paquets Python à installer
├── models/
│   ├── sources.yml            # Déclaration des tables brutes Snowflake
│   ├── schema.yml             # Documentation + tests des modèles
│   ├── bronze/bronze_client.sql
│   ├── silver/silver_client.sql
│   └── gold/gold_client.sql
├── tests/
│   └── test_no_negative_spent.sql   # Test personnalisé : total_spent > 0
└── setup/
    └── snowflake_setup.sql    # Droit CREATE SCHEMA à donner une fois
```

> `sources.yml` et `schema.yml` doivent être **dans `models/`** : dbt ne lit les
> fichiers YAML de modèles que dans les dossiers déclarés en `model-paths`.

---

## Étape 1 : Préparer Snowflake (une seule fois)

Dans une worksheet Snowflake, exécute `setup/snowflake_setup.sql`.
Le rôle `tasty_data_engineer` n'a que `USAGE` sur la base : sans ce `GRANT CREATE SCHEMA`,
dbt ne peut pas créer ses schémas et `dbt run` échoue avec *Insufficient privileges*.

## Étape 2 : Installer dbt

```bash
# Créer un environnement Python isolé
python -m venv .venv

# L'activer
.venv\Scripts\activate          # Windows (PowerShell / cmd)
source .venv/bin/activate       # Mac / Linux

# Installer dbt-core + l'adaptateur Snowflake
pip install -r requirements.txt

# Vérifier
dbt --version
```

## Étape 3 : Configurer la connexion

Le `profiles.yml` lit les identifiants dans des **variables d'environnement**
pour qu'aucun mot de passe ne finisse sur GitHub.

```powershell
# Windows PowerShell (valable pour la session en cours)
$env:SNOWFLAKE_ACCOUNT  = "monorg-moncompte"
$env:SNOWFLAKE_USER     = "ADAM"
$env:SNOWFLAKE_PASSWORD = "********"
```
```bash
# Mac / Linux
export SNOWFLAKE_ACCOUNT="monorg-moncompte"
export SNOWFLAKE_USER="ADAM"
export SNOWFLAKE_PASSWORD="********"
```

L'identifiant de compte se trouve dans Snowsight : menu en bas à gauche →
*Connect a tool to Snowflake* / *Account identifier* (format `ORG-COMPTE`).

Ensuite, tester la connexion :

```bash
dbt debug
```
Tout doit être `OK` (*profiles.yml file*, *dbt_project.yml file*, *Connection test*).

---

## Étape 4 : Les commandes dbt, dans l'ordre

| Commande | Ce qu'elle fait |
|---|---|
| `dbt debug` | Vérifie la config et la connexion Snowflake |
| `dbt parse` | Vérifie que le projet est valide (YAML, ref, source) sans rien exécuter |
| `dbt ls` | Liste tous les modèles, sources et tests du projet |
| `dbt compile` | Traduit le Jinja (`ref`, `source`) en vrai SQL → `target/compiled/` |
| `dbt run` | Crée les vues/tables dans Snowflake |
| `dbt test` | Lance tous les tests (schema.yml + dossier tests/) |
| `dbt build` | `run` + `test` modèle par modèle, dans l'ordre des dépendances |
| `dbt show -s silver_client --limit 10` | Affiche un aperçu des données d'un modèle |
| `dbt docs generate` puis `dbt docs serve` | Génère et ouvre la documentation + le graphe de lignage |
| `dbt clean` | Supprime `target/` et `dbt_packages/` |

### Sélectionner des modèles avec `-s` (`--select`)

```bash
dbt run -s bronze_client          # un seul modèle
dbt run -s silver_client+         # silver ET tout ce qui en dépend (gold)
dbt run -s +gold_client           # gold ET tout ce dont il dépend (bronze, silver)
dbt run -s models/gold            # tout un dossier
dbt test -s gold_client           # les tests d'un seul modèle
dbt run --full-refresh            # reconstruit tout de zéro
```

### Parcours conseillé pour apprendre

```bash
dbt debug
dbt compile -s silver_client      # regarde target/compiled/... : le ref() est devenu un vrai nom de table
dbt run -s bronze_client          # va voir la vue DBT_ADAM_BRONZE.BRONZE_CLIENT dans Snowflake
dbt run -s silver_client
dbt test -s silver_client
dbt build                         # tout le pipeline + tous les tests
dbt docs generate
dbt docs serve                    # onglet "Lineage graph" : ton schéma Bronze → Silver → Gold
```

### Où sont créés les objets dans Snowflake ?

dbt concatène le schéma cible (`dbt_adam`) et le schéma de la couche (`+schema`) :

| Modèle | Objet Snowflake |
|---|---|
| bronze_client | `FROSTBYTE_TASTY_BYTES.DBT_ADAM_BRONZE.BRONZE_CLIENT` (vue) |
| silver_client | `FROSTBYTE_TASTY_BYTES.DBT_ADAM_SILVER.SILVER_CLIENT` (table) |
| gold_client   | `FROSTBYTE_TASTY_BYTES.DBT_ADAM_GOLD.GOLD_CLIENT` (table) |

C'est le comportement par défaut de dbt : chaque développeur a ses propres schémas
et ne marche pas sur ceux des autres.

---

## Étape 5 : Mettre le projet sur GitHub

### 5.1 Créer le dépôt vide sur GitHub
github.com → **New repository** → nom `dbt_client_project` → **ne coche pas**
« Add a README » (il existe déjà) → *Create repository*.

### 5.2 Premier envoi

```bash
git init
git add .
git status                        # vérifie qu'il n'y a ni target/, ni .venv/, ni .env
git commit -m "Initialisation du projet dbt : couches bronze, silver, gold"
git branch -M main
git remote add origin https://github.com/<ton-pseudo>/dbt_client_project.git
git push -u origin main
```

### 5.3 Travailler avec des branches (bonne pratique)

```bash
git checkout -b feature/ajout-segment-vip     # nouvelle branche
# ... modifications des modèles ...
dbt build                                     # on vérifie que tout passe
git add .
git commit -m "Ajout du segment VIP dans gold_client"
git push -u origin feature/ajout-segment-vip
```
Puis sur GitHub : **Compare & pull request** → relecture → **Merge** dans `main`.
Pour récupérer `main` à jour en local : `git checkout main` puis `git pull`.

### Ce qui ne doit JAMAIS aller sur GitHub
Le `.gitignore` exclut déjà : `target/`, `logs/`, `dbt_packages/`, `.venv/`, `.env`.
Ne mets jamais de mot de passe en dur dans `profiles.yml`.

---

## Logique des couches

**Bronze** : `select *` sur la source, matérialisée en vue (aucun stockage).

**Silver** :
- *Nettoyage* : `TRIM(UPPER(...))` sur noms, ville, pays…
- *Standardisation* : email en minuscules, dates via `TRY_TO_DATE`, `children_count` converti en nombre
- *Enrichissement* : `age` et `jours_inscription`
- *Filtrage* : exclusion des `customer_id` nuls

**Gold** :
- *Jointure* avec `ORDER_HEADER` et `ORDER_DETAIL`. Le détail est d'abord agrégé
  **par commande**, sinon `order_total` serait compté une fois par article.
- *Agrégation* : nombre de commandes, total dépensé, nombre d'articles, panier moyen, 1re/dernière commande
- *Segmentation* : > 10 000 → PLATINUM, > 5 000 → GOLD, > 1 000 → SILVER, sinon BRONZE

> ⚠️ `order_total` est exprimé dans la **devise locale** de chaque commande
> (`order_currency` : USD, EUR, GBP…). Pour un vrai usage métier, il faudrait
> convertir dans une devise unique avant de segmenter.

## Les tests

| Type | Où | Exemple |
|---|---|---|
| Tests génériques | `models/schema.yml` | `unique`, `not_null`, `accepted_values` |
| Test personnalisé | `tests/*.sql` | `test_no_negative_spent.sql` |

Un test **réussit quand sa requête ne renvoie aucune ligne**.
En cas d'échec, `dbt test --store-failures` enregistre les lignes fautives dans Snowflake pour les analyser.

## Dépannage

| Erreur | Cause probable |
|---|---|
| `Env var required but not provided: 'SNOWFLAKE_ACCOUNT'` | Variables d'environnement non définies dans ce terminal (étape 3) |
| `Insufficient privileges to operate on database` | Étape 1 non faite |
| `Object 'CUSTOMER_LOYALTY' does not exist` | Mauvais rôle, ou script Tasty Bytes pas exécuté |
| `gold_client` très long | `ORDER_DETAIL` contient des centaines de millions de lignes : passe temporairement `tasty_de_wh` en `MEDIUM` |
