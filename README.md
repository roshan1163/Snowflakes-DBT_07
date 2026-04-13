# Snowflakes-DBT_07
project on the ELT using dbt for transformation and the snowflakes as the native data warehouse and perform melladious architecture 

=======================================================================
  DBT + SNOWFLAKE PROJECT NOTES
  Project: oltp_aws_dbt_snowflake_project
=======================================================================


-----------------------------------------------------------------------
1. PROJECT FOLDER STRUCTURE
-----------------------------------------------------------------------

oltp_aws_dbt_snowflake_project/
|
|-- dbt_project.yml          --> Main project config (materialization, schema, paths)
|-- profiles.yml             --> Snowflake connection settings
|
|-- models/
|   |-- sources/
|   |   |-- sources.yml      --> Declares raw Snowflake tables as dbt sources
|   |
|   |-- bronze/              --> Bronze layer (raw ingestion from source)
|   |   |-- bronze_bookings.sql
|   |   |-- bronze_host.sql
|   |   |-- bronze_listings.sql
|   |   |-- incremental_load.sql
|   |   |-- properties.yml   --> Model-level overrides (materialization per model)
|   |
|   |-- Tsilver/             --> Silver layer (cleaned, transformed data)
|       |-- silver_bookings.sql
|       |-- silver_listings.sql
|
|-- macros/                  --> Reusable Jinja functions
|   |-- multiply.sql
|   |-- tag.sql
|   |-- Trimmer.sql
|   |-- generate_schema_name.sql
|
|-- analyses/                --> SQL analysis files (not materialized)
|-- tests/                   --> Data quality tests
|-- seeds/                   --> Static CSV data
|-- snapshots/               --> SCD Type 2 snapshots
|-- target/                  --> Compiled SQL output (auto-generated, do not edit)


-----------------------------------------------------------------------
2. PROFILES.YML — Snowflake Connection Settings
-----------------------------------------------------------------------

Location: oltp_aws_dbt_snowflake_project/profiles.yml
          (also at C:/Users/<user>/.dbt/profiles.yml — global location)

--- File Content ---

oltp_aws_dbt_snowflake_project:       --> must match "profile" in dbt_project.yml
  outputs:
    dev:
      type: snowflake                  --> adapter type
      account: QXSMHZP-OC65126        --> Snowflake account identifier
      user: RONALDO                    --> Snowflake username
      password: "Roshan@1648103$"      --> Snowflake password
      role: ACCOUNTADMIN               --> Snowflake role to use
      database: SNOWFLAKE7             --> Default database in Snowflake
      schema: dbt_schema               --> Default schema (used when no custom schema set)
      warehouse: COMPUTE_WH            --> Snowflake virtual warehouse
      threads: 1                       --> Number of parallel model runs
  target: dev                          --> Which output to use by default

--- Key Points ---

- The "profile" name at the top must match "profile" in dbt_project.yml exactly.
- "schema" here is the DEFAULT schema. Custom schemas defined in dbt_project.yml
  or generate_schema_name macro will OVERRIDE this.
- "threads: 1" means models run one at a time (sequential).
  Increase to run multiple models in parallel.
- target: dev means dbt uses the "dev" output by default.
  You can switch targets with: dbt run --target prod


-----------------------------------------------------------------------
3. DBT_PROJECT.YML — Main Project Configuration
-----------------------------------------------------------------------

--- File Content ---

name: 'oltp_aws_dbt_snowflake_project'   --> project name (must match profile name)
version: '1.0.0'
profile: 'oltp_aws_dbt_snowflake_project' --> links to profiles.yml

model-paths: ["models"]                   --> where dbt looks for SQL model files
analysis-paths: ["analyses"]              --> analysis SQL files (not materialized)
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]                   --> where dbt looks for macros
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  oltp_aws_dbt_snowflake_project:         --> must match project name
    demo:
      +materialized: table                --> all models in /models/demo/ become tables
    bronze:
      +materialized: table                --> all models in /models/bronze/ become tables
      +schema: bronze                     --> creates/uses BRONZE schema in Snowflake
    Tsilver:
      +materialized: table                --> all models in /models/Tsilver/ become tables
      +schema: silver                     --> creates/uses SILVER schema in Snowflake

--- Key Points ---

- The folder name under models/ MUST match the key under "models:" in dbt_project.yml.
  e.g., folder "Tsilver" maps to "Tsilver:" in dbt_project.yml.
- "+schema: silver" tells dbt to place all Tsilver models in the SILVER schema.
- "+materialized" sets the default materialization for ALL models in that folder.
- Individual models can override this in their own config block or properties.yml.


-----------------------------------------------------------------------
4. SOURCES.YML — Declaring Raw Source Tables
-----------------------------------------------------------------------

Location: models/sources/sources.yml

--- File Content ---

version: 2

sources:
  - name: stagging                         --> logical source name used in SQL
    database: snowflake7                   --> Snowflake database
    schema: stagging                       --> Snowflake schema where raw tables live
    tables:
      - name: bookings                     --> raw table name
      - name: hosts
      - name: listings

--- How to Use in SQL ---

Instead of hardcoding table paths, use the source() function:

    select * from {{ source('stagging', 'bookings') }}

This compiles to:

    select * from SNOWFLAKE7.stagging.bookings

--- Why Use Sources Instead of Hardcoding ---

- If database or schema changes, you only update sources.yml — not every SQL file.
- dbt can track lineage (knows this model reads from a raw source).
- You can add tests and freshness checks to sources.
- dbt generates documentation for sources automatically.

--- Source Freshness (optional) ---

    - name: bookings
      freshness:
        warn_after: {count: 24, period: hour}
      loaded_at_field: CREATED_AT

Run: dbt source freshness


-----------------------------------------------------------------------
5. PROPERTIES.YML — Model-Level Configuration Override
-----------------------------------------------------------------------

Location: models/bronze/properties.yml  (can exist in any model folder)

--- File Content ---

version: 2

models:
  - name: bronze_host                   --> model name (must match SQL filename)
    config:
      materialized: view                --> override: this specific model is a VIEW
                                            even though bronze/ default is table

--- Key Points ---

- Used to override settings for individual models.
- "name" must exactly match the SQL file name (without .sql).
- You can also add descriptions, tests, and column documentation here.

--- Extended Example ---

models:
  - name: bronze_bookings
    description: "Raw bookings from Snowflake staging layer"
    config:
      materialized: table
    columns:
      - name: BOOKING_ID
        description: "Primary key"
        tests:
          - unique
          - not_null


-----------------------------------------------------------------------
6. CONFIG PRECEDENCE — Which Setting Wins?
-----------------------------------------------------------------------

When the same setting (e.g., materialized) is defined in multiple places,
dbt follows this priority order (highest wins):

  1. Config block inside the SQL file itself           (HIGHEST PRIORITY)
  2. properties.yml in the same folder as the model
  3. dbt_project.yml folder-level settings             (LOWEST PRIORITY)

--- Example ---

dbt_project.yml sets:
    bronze:
      +materialized: table          --> default for all bronze models

properties.yml sets:
    - name: bronze_host
      config:
        materialized: view          --> overrides dbt_project.yml for bronze_host only

bronze_host.sql has no config block  --> so properties.yml wins

Result: bronze_host is a VIEW, all other bronze models are TABLEs.

--- Another Example ---

silver_bookings.sql has:
    {{ config(materialized="incremental", unique_key='BOOKING_ID') }}

Even if dbt_project.yml says "+materialized: table" for Tsilver,
the SQL file config block WINS. silver_bookings becomes incremental.

--- Summary Table ---

  Priority | Where Defined            | Scope
  ---------|--------------------------|--------------------------------
  1 (High) | config() in .sql file    | That specific model only
  2        | properties.yml config    | That specific model only
  3 (Low)  | dbt_project.yml +key     | All models in that folder


-----------------------------------------------------------------------
7. MODELS — Bronze Layer
-----------------------------------------------------------------------

The bronze layer ingests raw data directly from Snowflake source tables.
No transformations — just a direct read.

--- bronze_bookings.sql ---

  select * from {{ source('stagging', 'bookings') }}

  Materialization: table (from dbt_project.yml)
  Schema: bronze
  What it does: Copies the raw bookings table from stagging schema into bronze.

--- bronze_host.sql ---

  select * from {{ source('stagging', 'hosts') }}

  Materialization: view (overridden in properties.yml)
  Schema: bronze
  What it does: Creates a view (no physical data copy) pointing to the raw hosts table.

--- bronze_listings.sql ---

  select * from {{ source('stagging', 'listings') }}

  Materialization: table (from dbt_project.yml)
  Schema: bronze
  What it does: Copies the raw listings table into bronze.

--- incremental_load.sql ---

  {{ config(materialized='incremental') }}

  select * from {{ ref('bronze_bookings') }}

  {% if is_incremental() %}
    where CREATED_AT > (select max(CREATED_AT) from {{ this }})
  {% endif %}

  Materialization: incremental (overrides dbt_project.yml via config block)
  Schema: bronze
  What it does: Loads new rows from bronze_bookings that are newer than the
                latest CREATED_AT already in this table.
  Note: Uses ref() not source() because it reads from another dbt model.


-----------------------------------------------------------------------
8. MODELS — Tsilver (Silver) Layer
-----------------------------------------------------------------------

The silver layer cleans and transforms bronze data. It uses macros and
incremental loading with delta + upsert pattern.

--- silver_bookings.sql ---

  {{ config(materialized="incremental", unique_key='BOOKING_ID') }}

  select
      BOOKING_ID,
      LISTING_ID,
      BOOKING_DATE,
      {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} as TOTAL_BOOKING_AMOUNT,
      BOOKING_STATUS,
      CREATED_AT
  from {{ ref('bronze_bookings') }}

  {% if is_incremental() %}
    where CREATED_AT > (select max(CREATED_AT) from {{ this }})
  {% endif %}

  What it does:
  - Reads from bronze_bookings (using ref)
  - Calls the multiply macro to calculate total booking amount
  - Loads incrementally: only new rows each run
  - Uses unique_key to upsert (update existing, insert new)

--- silver_listings.sql ---

  {{ config(materialized="incremental", unique_key='LISTING_ID') }}

  select
      *,
      {{ tag('price_per_night') }} as price_per_night_tag
  from {{ ref('bronze_listings') }}

  {% if is_incremental() %}
    where created_at > (select max(created_at) from {{ this }})
  {% endif %}

  What it does:
  - Reads all columns from bronze_listings
  - Calls the tag macro to categorize price_per_night as low/medium/high
  - Loads incrementally with upsert on LISTING_ID


-----------------------------------------------------------------------
9. MACROS — Reusable Jinja Functions
-----------------------------------------------------------------------

Macros are stored in the /macros/ folder and work like functions.
They are written in Jinja templating language and generate SQL at compile time.

Syntax:
    {% macro macro_name(param1, param2) %}
        ... SQL or Jinja logic ...
    {% endmacro %}

Called in SQL files using:
    {{ macro_name(arg1, arg2) }}

--- multiply.sql ---

  {% macro multiply(x, y, precision) %}
      round({{ x }} * {{ y }}, 2)
  {% endmacro %}

  Usage in silver_bookings.sql:
      {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }}

  Compiles to:
      round(NIGHTS_BOOKED * BOOKING_AMOUNT, 2)

  Purpose: Avoids repeating the round() expression in multiple models.
           Change the logic once in the macro, it updates everywhere.

--- tag.sql ---

  {% macro tag(col) %}
      case
          when {{ col }} <= 100 then 'low'
          when {{ col }} <= 200 then 'medium'
          else 'high'
      end
  {% endmacro %}

  Usage in silver_listings.sql:
      {{ tag('price_per_night') }} as price_per_night_tag

  Compiles to:
      case
          when price_per_night <= 100 then 'low'
          when price_per_night <= 200 then 'medium'
          else 'high'
      end as price_per_night_tag

  Purpose: Generates a SQL CASE WHEN expression for any column.
           NOTE: Jinja if/elif is compile-time, not runtime.
                 Always use SQL CASE WHEN for row-level logic.

--- generate_schema_name.sql ---

  {% macro generate_schema_name(custom_schema_name, node) -%}
      {%- set default_schema = target.schema -%}
      {%- if custom_schema_name is none -%}
          {{ default_schema }}
      {%- else -%}
          {{ custom_schema_name | trim }}
      {%- endif -%}
  {%- endmacro %}

  Purpose: Controls how dbt names schemas in Snowflake.
  Default dbt behavior: schema = default_schema + "_" + custom_schema
                        e.g., dbt_schema_bronze

  This custom macro OVERRIDES that behavior:
  - If no custom schema is set  --> use default schema from profiles.yml
  - If custom schema IS set     --> use ONLY the custom schema name (e.g., bronze, silver)

  This is why your models land in BRONZE and SILVER schemas directly
  instead of DBT_SCHEMA_BRONZE and DBT_SCHEMA_SILVER.


-----------------------------------------------------------------------
10. JINJA TEMPLATING — Syntax Reference
-----------------------------------------------------------------------

dbt uses Jinja2 templating inside SQL files.
There are three types of Jinja tags:

  {{ ... }}   --> Expression tag: evaluates and outputs a value
  {% ... %}   --> Statement tag: used for logic (if, for, set, macro)
  {# ... #}   --> Comment tag: ignored during compilation

--- Built-in dbt Jinja Functions ---

1. source(source_name, table_name)
   Reads from a raw Snowflake table declared in sources.yml.
   Example: {{ source('stagging', 'bookings') }}
   Compiles to: SNOWFLAKE7.stagging.bookings

2. ref(model_name)
   References another dbt model. Automatically builds in correct order.
   Example: {{ ref('bronze_bookings') }}
   Compiles to: SNOWFLAKE7.bronze.bronze_bookings

3. config(...)
   Sets model-level configuration inside the SQL file.
   Example: {{ config(materialized='incremental', unique_key='BOOKING_ID') }}

4. is_incremental()
   Returns TRUE if the target table already exists (subsequent runs).
   Returns FALSE on the very first run.
   Used to add a WHERE clause that filters only new/changed rows.
   Example:
       {% if is_incremental() %}
         where CREATED_AT > (select max(CREATED_AT) from {{ this }})
       {% endif %}

5. this
   Refers to the current model's table in Snowflake.
   Used inside is_incremental() to query the existing target table.
   Example: select max(CREATED_AT) from {{ this }}

--- Jinja Variables ---

   {% set my_var = 'hello' %}
   {{ my_var }}

--- Jinja Filters ---

   {{ custom_schema_name | trim }}     --> removes whitespace
   {{ column_name | upper }}           --> converts to uppercase
   {{ value | lower }}                 --> converts to lowercase

--- Jinja For Loop (used in advanced macros) ---

   {% set columns = ['col1', 'col2', 'col3'] %}
   {% for col in columns %}
       {{ col }},
   {% endfor %}

--- Jinja Conditionals ---

   {# WRONG for runtime SQL logic: #}
   {% if col > 100 %}low{% endif %}     --> col is a STRING here, not a SQL value!

   {# CORRECT for runtime SQL logic: use SQL CASE WHEN #}
   case when {{ col }} > 100 then 'low' else 'high' end

   Rule: Use {% if %} for compile-time decisions (env, config flags).
         Use SQL CASE WHEN for row-level data logic.


-----------------------------------------------------------------------
11. HOW IT ALL CONNECTS — End-to-End Flow
-----------------------------------------------------------------------

1. profiles.yml      --> Tells dbt HOW to connect to Snowflake
                         (account, user, database, warehouse, schema)

2. dbt_project.yml   --> Tells dbt WHERE models are and their default settings
                         (folder structure, materialization, schema mapping)

3. sources.yml       --> Tells dbt WHAT raw tables exist in Snowflake
                         (source name, database, schema, table names)

4. macros/           --> Reusable Jinja functions to generate SQL snippets
                         (multiply, tag, generate_schema_name)

5. models/bronze/    --> Ingests raw data from sources using source()
                         No transformations. Just reads raw tables.

6. models/Tsilver/   --> Transforms bronze data using ref()
                         Applies macros, incremental logic, business rules.

7. properties.yml    --> Overrides default settings for specific models
                         (e.g., make bronze_host a view instead of table)

8. generate_schema_name macro --> Controls the final schema name in Snowflake
                         Ensures "bronze" stays "bronze" not "dbt_schema_bronze"

--- Data Flow Diagram ---

Snowflake RAW (stagging schema)
    |
    | source('stagging', 'bookings') / source('stagging', 'listings') / source('stagging', 'hosts')
    v
Bronze Layer (BRONZE schema in Snowflake)
    bronze_bookings (table)
    bronze_listings (table)
    bronze_host     (view)
    incremental_load (incremental table)
    |
    | ref('bronze_bookings') / ref('bronze_listings')
    v
Silver Layer (SILVER schema in Snowflake)
    silver_bookings  (incremental, upsert on BOOKING_ID)  <-- uses multiply macro
    silver_listings  (incremental, upsert on LISTING_ID)  <-- uses tag macro


-----------------------------------------------------------------------
12. COMMON DBT COMMANDS
-----------------------------------------------------------------------

dbt run                          --> Run all models
dbt run --select model_name      --> Run a single model
dbt run --select Tsilver         --> Run all models in Tsilver folder
dbt compile                      --> Compile Jinja to plain SQL (check target/ folder)
dbt ls                           --> List all models dbt knows about
dbt test                         --> Run data quality tests
dbt source freshness             --> Check if source data is fresh
dbt docs generate                --> Generate project documentation
dbt docs serve                   --> Open documentation in browser
dbt clean                        --> Delete target/ and dbt_packages/ folders


-----------------------------------------------------------------------
END OF NOTES
-----------------------------------------------------------------------
