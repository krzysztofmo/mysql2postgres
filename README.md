# mysql-to-postgres - MySQL to PostgreSQL Data Translation

MRI or jruby supported.

With a bit of a modified rails database.yml configuration, you can integrate mysql-to-postgres into a project.

Sample Configuration file:

    default: &default
      adapter: jdbcpostgresql
      encoding: unicode
      pool: 4
      username: terrapotamus
      password: default
      host: 127.0.0.1
  
    development: &development
      <<: *default
      database: default_development

    test: &test
      <<: *default
      database: default_test

    production: &production
      <<: *default
      database: default_production

    mysql_data_source: &pii
      host: localhost
      port: 3306
      username: username
      password: default
      database: awesome_possum

    mysql2psql:
      mysql:
        <<: *pii
    
      destination:
        production:
          <<: *production
        test: 
          <<: *test
        development:
          <<: *development
      
      tables:
      - countries
      - samples
      - universes
      - variable_groups
      - variables
      - sample_variables

      # if suppress_data is true, only the schema definition will be exported/migrated, and not the data
      suppress_data: false

      # if suppress_ddl is true, only the data will be exported/imported, and not the schema
      suppress_ddl: true

      # if force_truncate is true, forces a table truncate before table loading
      force_truncate: false

      preserve_order: true

      remove_dump_file: true
  
      report_status:  json    # false, json, xml

