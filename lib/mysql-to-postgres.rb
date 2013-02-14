# -*- encoding : utf-8 -*-

if RUBY_PLATFORM == 'java'
  require 'active_record'
  require 'postgres-pr/postgres-compat'
else
  require 'pg_ext'
  require 'pg/exceptions'
  require 'pg/constants'
  require 'pg/connection'
  require 'pg/result'
  require 'pg'
end

require 'mysql2psql/errors'
require 'mysql2psql/version'
require 'mysql2psql/config'
require 'mysql2psql/converter'
require 'mysql2psql/mysql_reader'
require 'mysql2psql/writer'
require 'mysql2psql/postgres_writer'
require 'mysql2psql/postgres_db_writer.rb'

class Mysql2psql
  
  attr_reader :options, :reader, :writer
  
  def initialize(yaml)
    @options = Config.new( yaml )
  end
  
  def convert
    @reader = MysqlReader.new( options )
    @writer = PostgresDbWriter.new( options )
    begin
      Converter.new( reader, writer, options ).convert
    rescue Mysql2psql::ConversionError => err
      $stderr.puts err
    end
  end

end