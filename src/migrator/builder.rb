class MigrationBuilder
  def self.comment= s
    @@comment = s
  end

  def self.comment_delimiter= s
    @@comment_delimiter = s
  end

  def self.metrics_prefix= s
    @@metrics_prefix = s
  end

  def initialize manifest
    @manifest = manifest
    @builders = {}
  end

  def build
    content = ''
    trigger :start, content
    @manifest.migrations.each do |migration|
      trigger :start_migration, content, :migration => migration
      content << migration.contents(@manifest.configuration)
      trigger :end_migration, content, :migration => migration
    end
    trigger :end, content
    content
  end

  def on event, *builders
    builders.each do |builder|
      builder.class.class_eval('include AbstractBuilder')
      (@builders[event] ||= []) << builder
    end
  end

  def trigger event, content, options = {}
    @builders[event].try :each do |builder|
      builder.instance_variable_set :@content, content
      builder.instance_variable_set :@builder, self
      builder.instance_variable_set :@manifest, @manifest
      builder.instance_variable_set :@event, event
      options.each_pair{ |k,v| builder.instance_variable_set "@#{k}".to_sym, v }
      builder.build
    end
  end

  def comment
    @@comment
  end

  def comment_delimiter
    @@comment_delimiter
  end

  def metrics_prefix
    @@metrics_prefix
  end

  private

  @@comment = ''
  @@comment_delimiter = ''
  @@metrics_prefix = ''
end

module AbstractBuilder
  def line text = nil, options = {}
    new_line = !options.key?(:new) || options[:new] ? "\n" : nil
    @content << "#{text}#{new_line}"
  end

  def comment text = nil, options = {}
    line text.to_s.gsub(/^/, @builder.comment), options
  end

  def title text
    delimiter
    delimiter
    comment text
    delimiter
    delimiter
  end

  def delimiter
    comment @builder.comment_delimiter
  end
end

class TitleSection
  def build
    line
    comment 'LOTARIS MIGRATION SCRIPT'
    comment "Generated at: #{Time.now}"
  end
end

class ConfigurationSection
  def build
    line
    comment 'CONFIGURATION'
    comment @manifest.configuration.description
  end
end

class RequisitesSection
  def build
    line
    show_requisites :pre
    line
    show_requisites :post
  end

  private

  def show_requisites type
    comment "#{type.to_s.upcase}-REQUISITES"
    reqs = requisites type
    if reqs.empty?
      comment "No #{type}-requisites were detected in the migrations."
      return
    end
    comment "#{reqs.length} #{type}-requisites were detected in the migrations."
    reqs.each_with_index do |req_hash,i|
      line
      comment "   #{type.to_s.capitalize}-requisite #{i + 1} (#{req_hash[:migration].description}):"
      comment req_hash[:annotation].requisite.to_s.gsub(/^/, '     ')
    end
  end

  def requisites type
    @manifest.migrations.inject([]) do |memo,m|
      m.annotations.select{ |a| requisite? a, type }.each do |a|
        memo << { :annotation => a, :migration => m }
      end
      memo
    end
  end

  def requisite? annotation, type
    annotation.kind_of?(RequisiteAnnotation) && annotation.type.to_s == type.to_s
  end
end

class ManifestSection
  def build
    line
    comment 'MANIFEST'
    comment 'The following table is the migration manifest.'
    comment 'It describes which migrations are run in which order.'
    line
    comment @manifest
  end
end

class MigrationTitleSection
  def build
    if @event == :start_migration
      title "Start: #{@migration.description}"
      line
    elsif @event == :end_migration
      line
      title "End: #{@migration.description}"
    end
  end
end

class AbstractMysqlSection
  private

  def mysql_script_duration_var migration
    "@`#{@builder.metrics_prefix}DURATION_OF_#{File.basename migration.file}`"
  end

  def mysql_script_duration_var migration
    "@`#{@builder.metrics_prefix}DURATION_OF_#{File.basename migration.file}`"
  end

  def compute_mysql_var name
    line "SET #{mysql_var_name name} = ((#{mysql_var_value name}) - #{mysql_var_name name});"
  end

  def store_mysql_var name
    line "SET #{mysql_var_name name} = (#{mysql_var_value name});"
  end

  def mysql_table name
    "`#{@manifest.configuration.database}`.`#{name}`"
  end

  def mysql_var_name name
    "@#{@builder.metrics_prefix}#{name}"
  end

  def mysql_var_value name
    "SELECT `VARIABLE_VALUE` FROM `INFORMATION_SCHEMA`.`SESSION_STATUS` WHERE `VARIABLE_NAME` = '#{name}'"
  end
end

class MigrationMetricsSection < AbstractMysqlSection
  def build
    if @event == :start_migration
      start_migration_metrics
      line
    elsif @event == :end_migration
      line
      end_migration_metrics
    end
  end

  def start_migration_metrics
    comment "Metrics: note start time of #{File.basename @migration.file}."
    line "SET #{mysql_script_duration_var @migration} = (NOW());"
  end

  def end_migration_metrics
    line unless @migration.contents(@configuration).match /\n\z/m
    comment "Metrics: compute duration of #{File.basename @migration.file}."
    line "SET #{mysql_script_duration_var @migration} = (TIMESTAMPDIFF(SECOND, #{mysql_script_duration_var @migration}, NOW()));"
  end
end

class GlobalMetricsSection < AbstractMysqlSection
  MYSQL_METRIC_VARIABLES = [ :COM_ALTER_PROCEDURE, :COM_ALTER_TABLE, :COM_CREATE_INDEX, :COM_CREATE_PROCEDURE, :COM_CREATE_TABLE, :COM_DELETE, :COM_DELETE_MULTI, :COM_DROP_INDEX, :COM_DROP_PROCEDURE, :COM_DROP_TABLE, :COM_EMPTY_QUERY, :COM_EXECUTE_SQL, :COM_INSERT, :COM_INSERT_SELECT, :COM_LOCK_TABLES, :COM_PRELOAD_KEYS, :COM_PREPARE_SQL, :COM_RENAME_TABLE, :COM_REPLACE, :COM_REPLACE_SELECT, :COM_SELECT, :COM_SET_OPTION, :COM_TRUNCATE, :COM_UPDATE, :COM_UPDATE_MULTI, :CREATED_TMP_TABLES, :SLOW_QUERIES, :QCACHE_HITS, :SELECT_FULL_JOIN, :SELECT_FULL_RANGE_JOIN, :SELECT_RANGE, :SELECT_RANGE_CHECK, :SELECT_SCAN ]

  def build
    if @event == :start
      start_global_metrics
    elsif @event == :end
      end_global_metrics
    end
  end

  def start_global_metrics
    line
    title 'Start: storing migration metrics.'
    line
    comment 'Metrics: note starting values of variables.'
    line "SET #{mysql_var_name(:START_TIME)} = NOW();"
    [ :QUERIES, :BYTES_RECEIVED, :BYTES_SENT ].each{ |var| store_mysql_var var }
    MYSQL_METRIC_VARIABLES.each{ |var| store_mysql_var var }
    line
    title 'End: storing migration metrics.'
  end

  def store_global_metrics
    comment 'Metrics: compute difference of variables.'
    line "SET #{mysql_var_name(:END_TIME)} = (NOW());";
    [ :QUERIES, :BYTES_RECEIVED, :BYTES_SENT ].each{ |var| compute_mysql_var var }
    MYSQL_METRIC_VARIABLES.each{ |var| compute_mysql_var var }
  end

  def end_global_metrics
    title 'Start: storing migration metrics.'
    line
    store_global_metrics
    line
    comment 'Metrics: store information about the started migration.'
    
    attrs = {
      :VERSIONFROM => @manifest.configuration.migrate_from_release,
      :VERSIONTO => @manifest.configuration.migrate_to_release,
      :REVISIONFROM => @manifest.configuration.first_revision,
      :REVISIONTO => @manifest.configuration.last_revision,
      :DATESTART => mysql_var_name(:START_TIME).to_sym, :DATEEND => mysql_var_name(:END_TIME).to_sym,
      :DURATION => "TIMESTAMPDIFF(SECOND, #{mysql_var_name(:START_TIME)}, #{mysql_var_name(:END_TIME)})".to_sym,
      :MANIFEST => @manifest.to_s, :QUERIES => mysql_var_name(:QUERIES).to_sym,
      :BYTESRECEIVED => mysql_var_name(:BYTES_RECEIVED).to_sym,
      :BYTESSENT => mysql_var_name(:BYTES_SENT).to_sym
    }
    keys = attrs.keys.sort{ |a,b| a.to_s <=> b.to_s }
    line "INSERT INTO #{mysql_table :LIB_MIG_INFO} ", :new => false
    line "(#{keys.collect{ |k| %/`#{k}`/ }.join(', ')}) VALUES (", :new => false
    keys.each do |k|
      line ", ", :new => false unless k == keys.first
      if attrs[k].kind_of?(Symbol) or attrs[k].kind_of?(Fixnum)
      	line attrs[k].to_s, :new => false
      else
        line "'#{attrs[k]}'", :new => false
      end
    end
    line ");"
    line
    line "SET #{mysql_var_name :LIB_MIG_INFO_ID} = (SELECT max(`ID`) FROM #{mysql_table :LIB_MIG_INFO});"
    line
    comment 'Metric: store metrics.'
    MYSQL_METRIC_VARIABLES.each do |var|
      line "INSERT INTO #{mysql_table :LIB_MIG_METRIC} (`NAME`, `METRICVALUE`, `MIGRATIONINFO_ID`) ", :new => false
      line "VALUES('#{var}', #{mysql_var_name var}, #{mysql_var_name :LIB_MIG_INFO_ID});"
    end
    line
    comment 'Metrics: store duration of each script.'
    @manifest.migrations.each do |migration|
      line "INSERT INTO #{mysql_table :LIB_MIG_PART} (`NAME`, `DURATION`, `MIGRATIONINFO_ID`) ", :new => false
      line "VALUES ('#{File.basename migration.file}', #{mysql_script_duration_var migration}, #{mysql_var_name :LIB_MIG_INFO_ID});"
    end
    line
    title 'End: storing migration metrics.'
  end
end

class LastCommitSection
  def build
    line
    line 'COMMIT;'
  end
end

class SpacerSection
  def initialize length = 5
    @length = length
  end

  def build
    @length.times{ line }
  end
end
