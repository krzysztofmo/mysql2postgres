# -*- encoding : utf-8 -*-

require 'mysql2psql/postgres_writer'
require 'mysql2psql/connection'

class Mysql2psql

class PostgresDbWriter < PostgresWriter
  attr_reader :connection

  BATCH_SIZE = 1000
  REPORT_INTERVAL_IN_SECONDS = 10

  def initialize(options)
    @connection = Connection.new(options)

    sql = <<-EOF
-- MySQL 2 PostgreSQL dump\n
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
EOF
    execute sql
  end
  
  def truncate(table)
    serial_key = nil
    maxval = nil
    
    table.columns.map do |column|
      if column[:auto_increment]
        serial_key = column[:name]
        maxval = column[:maxval].to_i < 1 ? 1 : column[:maxval] + 1
      end
    end

    sql = ''
    sql << <<-EOF
-- TRUNCATE #{table.name};
TRUNCATE #{PGconn.quote_ident(table.name)} CASCADE;

EOF
    if serial_key
    sql << <<-EOF
SELECT pg_catalog.setval(pg_get_serial_sequence('#{table.name}', '#{serial_key}'), #{maxval}, true);
EOF
    end
    execute sql
  end
  
  def write_table(table)
    sql = ''
    primary_keys = []
    serial_key = nil
    maxval = nil
    
    columns = table.columns.map do |column|
      if column[:auto_increment]
        serial_key = column[:name]
        maxval = column[:maxval].to_i < 1 ? 1 : column[:maxval] + 1
      end
      if column[:primary_key]
        primary_keys << column[:name]
      end
      "  " + column_description(column)
    end.join(",\n")
    
    if serial_key

      sql << <<-EOF
--
-- Name: #{table.name}_#{serial_key}_seq; Type: SEQUENCE; Schema: public
--

DROP SEQUENCE IF EXISTS #{table.name}_#{serial_key}_seq CASCADE;

CREATE SEQUENCE #{table.name}_#{serial_key}_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


SELECT pg_catalog.setval('#{table.name}_#{serial_key}_seq', #{maxval}, true);

EOF
    end

    sql << <<-EOF
-- Table: #{table.name}

-- DROP TABLE #{table.name};
DROP TABLE IF EXISTS #{PGconn.quote_ident(table.name)} CASCADE;

CREATE TABLE #{PGconn.quote_ident(table.name)} (
EOF

    sql << columns

    if primary_index = table.indexes.find {|index| index[:primary]}
      sql << ",\n  CONSTRAINT #{table.name}_pkey PRIMARY KEY(#{primary_index[:columns].map {|col| PGconn.quote_ident(col)}.join(", ")})"
    end

    sql << <<-EOF
\n)
WITHOUT OIDS;
EOF

    table.indexes.each do |index|
      next if index[:primary]
      unique = index[:unique] ? "UNIQUE " : nil
      sql << <<-EOF
DROP INDEX IF EXISTS #{PGconn.quote_ident(index[:name])} CASCADE;
CREATE #{unique}INDEX #{PGconn.quote_ident(index[:name])} ON #{PGconn.quote_ident(table.name)} (#{index[:columns].map {|col| PGconn.quote_ident(col)}.join(", ")});
EOF
    end
    execute sql
  end
  
  def write_indexes(table)
  end
  
  def write_constraints(table)
    sql = ''
    table.foreign_keys.each do |key|
      sql << "ALTER TABLE #{PGconn.quote_ident(table.name)} ADD FOREIGN KEY (#{key[:column].map{|c|PGconn.quote_ident(c)}.join(', ')}) REFERENCES #{PGconn.quote_ident(key[:ref_table])}(#{key[:ref_column].map{|c|PGconn.quote_ident(c)}.join(', ')}) ON UPDATE #{key[:on_update]} ON DELETE #{key[:on_delete]};\n"
    end
    execute sql
  end
  
  def write_contents(table, reader, columns_to_nullify_after_read = [])
    @row_count = table.count_rows
    connection.execute("COPY \"#{table.name}\" (#{table.columns.map { |column| PGconn.quote_ident(column[:name]) }.join(", ")}) FROM stdin;")
    columns_to_nullify = table.columns.select { |column| columns_to_nullify_after_read.include?(column[:name]) }.map { |column| table.columns.index(column) }
    reader.paginated_read(table, BATCH_SIZE) do |row, counter|
      columns_to_nullify.each { |i| row[i] = nil }
      process_row(table, row)
      connection.execute(row.join("\t") + "\n")
      print_info( counter )
    end
    connection.execute "\\.\n\n"
  end

  private
    def execute(sql)
      io = StringIO.new sql
      while line = io.gets
        connection.execute line
      end
    end

    def print_info(counter)
      @start_time = @start_time || Time.now
      if Time.now - @start_time > REPORT_INTERVAL_IN_SECONDS
        Rails.logger.info "Copied #{counter} records. Done: #{(100.0*counter/@row_count).round(1)}%"
        @start_time = Time.now
      end
    end

end

end