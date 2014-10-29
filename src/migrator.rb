#!/usr/bin/env ruby

# Created: 2011-01-17
# Author: Simon Oulevay (simon.oulevay@lotaris.com)
# Version: 2

require 'rubygems' # required for ruby 1.8

require File.expand_path(File.join(File.dirname(__FILE__), 'lotaris_libs'))
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'migrator'))
%w( migration manifest builder annotations ).each{ |custom_lib| require custom_lib }
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'branch'))
%w( branch ).each{ |custom_lib| require custom_lib }

###########################
### BASIC CONFIGURATION ###
###########################

# configure databases
Lotaris::Database.register_defaults!

# special migration filenames
DB_CREATE_SCRIPT_NAME = '_db_creation.sql'
DB_INIT_SCRIPT_NAME = '_db_init_data.sql'

# temporary directory where migrations are checked out
TMP_DIR_PATH = "/tmp/.lotaris.migrations.#{$$}"
# name of the directory where deployment-specific migrations are checked out within the temporary directory
SPECIAL_MIGRATIONS_DIR = :SPECIAL

# styles
Manifest.column_width = 25
MigrationBuilder.comment = '-- '
MigrationBuilder.comment_delimiter = '=' * 65
MigrationBuilder.metrics_prefix = 'DB_METRICS_'

############################
### CONFIGURATION OBJECT ###
############################

class Validator
  def enforce_presence_of_field field, message
    send "#{field}=", CL::UI.ask_or_exit(message) while send(field).blank?
  end

  def enforce_presence_of_boolean_field field, message
    send "#{field}=", CL::UI.parse_boolean(CL::UI.ask_or_exit(message)) while send(field).blank?
  end
end

class Configuration < Validator
  attr_accessor :first_revision, :last_revision, :init_database, :store_metrics,
  :load_manifest, :save_manifest, :keep_manifest, :build_directly, :environment,
  :migrate_to_release, :migrate_from_release, :checkout_from_release, :special_migrations,
  :repository_conf, :prefix, :suffix
  attr_reader :database

  def initialize
    @save_manifest, @load_manifest, @store_metrics, @checkout_from_release = true, true, true, :trunk
    @special_migrations = :contextuals
  end

  def special_migrations_dir
    @repository_conf.migrations.send "#{@special_migrations}_path"
  end

  def revision_range
    return nil if first_revision.blank?
    "#{first_revision}:" << (last_revision.blank? ? 'HEAD' : last_revision.to_s)
  end

  def revision_range= s
    if !s.match(/^\d+(:(\d+|HEAD))?$/i)
      warn "Revision range #{s} is not valid"
      self.first_revision, self.last_revision = nil, nil
      return
    end
    self.first_revision = s.split(/:/)[0].to_i
    self.last_revision = s.sub(/^\d+:?/, '')
    self.last_revision = nil if last_revision.blank? or last_revision.match(/HEAD/i)
    self.last_revision = last_revision.to_i unless last_revision.nil?
    if last_revision and last_revision < first_revision
      warn "Revision range #{s} must be ascending"
      self.first_revision, self.last_revision = nil, nil
    end
  end

  def includes_revision? r
    first_revision.present? and r >= first_revision and (last_revision.blank? or r <= last_revision)
  end

  def database= s
    @database = Lotaris::Database.find s
    if @database.try :shared
      warn "Database #{@database.name} cannot be migrated"
      @database = nil
    end
  end

  def description
    "Database: #{database}".tap do |desc|
      desc << "\nEnvironment: #{environment}"
      desc << "\nRevision range: #{revision_range}"
      desc << "\nMigrate from release: #{migrate_from_release}"
      desc << "\nMigrate to release: #{migrate_to_release}"
      desc << "\nCheckout from release: #{checkout_from_release}"
      desc << "\nAdditional scripts from: #{special_migrations_dir}"
      desc << "\nInitialize database: #{init_database}"
      desc << "\nStore metrics: #{store_metrics}"
      desc << "\nSave manifest: no" unless save_manifest
      desc << "\nLoad manifest: no" unless load_manifest
    end
  end
end

CONF = Configuration.new

#############################
### OPTIONS CONFIGURATION ###
#############################

name = File.basename __FILE__
action = 'generates a migration file for a specific database and environment'
script = CL::Options::Script.new name, action, :examples => [
  '-f 1.3-ALPHA -t 1.3-RC -r 4000 -d LIS -i',
  '-f 1.3-ALPHA -t 1.3-RC -r 5000:6000 -y'
]

script.register CL::Options::Option.new(:short => :f, :long => :from, :arity => 1,
  :description => 'the release your are migrating from (e.g. 1.1.2, 1.3-RC)'){ |rel|
    CONF.migrate_from_release = rel }

script.register CL::Options::Option.new(:short => :t, :long => :'to', :arity => 1,
  :description => 'the release you are migrating to (e.g. 1.1.2, 1.3-RC)'){ |rel|
    CONF.migrate_to_release = rel }

script.register CL::Options::Option.new(:short => :c, :long => :'checkout-from', :arity => 1,
  :description => 'the release you want to check out migrations from, TRUNK by default (e.g. TRUNK, 1.1.2, 1.3-RC)'){ |rel|
    CONF.checkout_from_release = rel }

script.register CL::Options::Option.new(:short => :d, :long => :database, :arity => 1,
  :description => 'migrate database NAME (e.g. PAS, LotarisLicenseServer, LotarisGatewayServer)'){ |db|
    CONF.database = db }

script.register CL::Options::Option.new(:short => :r, :long => :revision, :arity => 1,
  :description => 'the starting revision or revision range of migrations (e.g. 4000, 4000:5000, 4000:HEAD)'){ |rev|
    CONF.revision_range = rev }

script.register CL::Options::Option.new(:short => :e, :long => :environment, :arity => 1,
  :description => 'the migration environment (e.g. lanexpert, symantec-beta)'){ |env|
    CONF.environment = env }

script.register CL::Options::Option.new(:short => :i, :long => :init,
  :description => 'include db schema creation and initialization scripts (if present)'){
    CONF.init_database = true }

script.register CL::Options::Option.new(:long => :'no-init',
  :description => 'do not include db schema creation and initialization scripts'){
    CONF.init_database = false }

script.register CL::Options::Option.new(:short => :m, :long => :metrics,
  :description => 'store migration metrics in the database (adds queries at the beginning and end of the final script)'){
    CONF.store_metrics = true }

script.register CL::Options::Option.new(:long => :'no-metrics',
  :description => 'do not store migration metrics in the database'){
    CONF.store_metrics = false }
	
script.register CL::Options::Option.new(:long => :corrective,
  :description => 'use corrective directory to get contextual migration scripts'){
    CONF.special_migrations = :correctives }

script.register CL::Options::Option.new(:long => :build,
  :description => 'build the migration script without confirmation (and without editing the manifest)'){
    CONF.build_directly = true }

script.register CL::Options::Option.new(:long => :'keep-manifest',
  :description => 'keep the migration manifest after successful execution'){
    CONF.keep_manifest = true }

script.register CL::Options::Option.new(:long => :'no-save-manifest',
  :description => 'do not save the migration manifest'){
    CONF.save_manifest = false }

script.register CL::Options::Option.new(:long => :'no-load-manifest',
  :description => 'if an existing migration manifest is found, do not load it'){
    CONF.load_manifest = false }

script.register CL::Options::Option.new(:long => :'no-manifest',
  :description => 'same as using both --no-save-manifest and --no-load-manifest'){
    CONF.save_manifest, CONF.load_manifest = false, false }

script.register CL::Options::Option.new(:long => :prefix, :arity => 1,
  :description => 'add a prefix to the file name of the migration script'){ |prefix|
    CONF.prefix = prefix }

script.register CL::Options::Option.new(:long => :suffix, :arity => 1,
  :description => 'add a suffix to the file name of the migration script'){ |suffix|
    CONF.suffix = suffix }

script.register Lotaris::Database
script.register CL::UI

script.register_help_and_usage!

#########################
### CONSUME ARGUMENTS ###
#########################

# consume command-line arguments
script.consume

# complete unspecified configuration
CONF.enforce_presence_of_field :database, 'Please choose a database (e.g. PAS, LotarisLicenseServer): '
CONF.enforce_presence_of_field :revision_range, 'Please enter a range of revisions (e.g. 3000, 4000:5000, 6000:HEAD): '
CONF.enforce_presence_of_field :environment, 'Please enter the migration environment (e.g. lanexpert, symantec-beta): '
CONF.enforce_presence_of_field :migrate_from_release, 'Please enter the release you are migrating from (e.g. 1.1.2, 1.3-RC): '
CONF.enforce_presence_of_field :migrate_to_release, 'Please enter the release you are migrating to (e.g. 1.1.2, 1.3-RC): '
CONF.enforce_presence_of_field :checkout_from_release, 'Please enter the release you want to check out migrations from (e.g. TRUNK, 1.1.2, 1.3-rc): '
CONF.enforce_presence_of_boolean_field :init_database, 'Do you want to initialize the database? (yes/no): '
CONF.enforce_presence_of_boolean_field :store_metrics, 'Do you want to store migration metrics in the database? (yes/no): '

# validate presence of svn binary (:fixme)
#SVN.enforce_presence_of_field :binary, 'Please choose a valid SVN binary (e.g. /opt/local/bin/svn): '

#################
### EXECUTION ###
#################

# trap signals (see utils.rb)
CL::Signals.trap

# create temporary directory (see utils.rb)
TMP = CL::TemporaryDirectory.new TMP_DIR_PATH

repo = CONF.database.repository || :lme
svn_conf = Lotaris::Subversion.repository_conf repo
svn_client = Lotaris::Subversion.client :root_url => svn_conf.root, :working_copy => TMP.to_s

CONF.repository_conf = svn_conf

puts
puts CONF.description
CL::UI.confirm_or_exit

##############################
### CHECKOUT OF MIGRATIONS ###
##############################

# build list of databases to migrate (e.g. SLIB and LIS)
DATABASES = Lotaris::Database.list_for_migration CONF.database

branch = if CONF.checkout_from_release.to_s.strip.downcase.match /^trunk$/i
  Branch.new svn_conf.branch(:trunk)
else
  Branch.new(svn_conf.branch(:release)).tap{ |b| b.identifier = CONF.checkout_from_release }
end

MIGRATION_SOURCES = []
DEFAULT_MIGRATION_PARSERS = [
  StandardMigrationParser.new(CONF),
  StaticMigrationParser.new(CONF, DB_CREATE_SCRIPT_NAME, CONF.init_database){ |migration|
    migration.position.revision = -20 # parser for _db_creation.sql
    migration.description = "creation of #{migration.database}"
  },
  StaticMigrationParser.new(CONF, DB_INIT_SCRIPT_NAME, CONF.init_database){ |migration|
    migration.position.revision = -10 # parser for _db_init_data.sql
    migration.description = "data initialization of #{migration.database}"
  }
]

SPECIAL_MIGRATION_PARSERS = [
  SpecialMigrationParser.new(CONF)
]

DATABASES.each do |db|
  remote_dir = db.migrations_path
  local_dir = "#{TMP}/#{db.tag}"
  MIGRATION_SOURCES << MigrationSource.new(svn_client, branch.absolute_path, remote_dir, local_dir, db, DEFAULT_MIGRATION_PARSERS)
end

special_migrations_path = "#{CONF.special_migrations_dir}/#{CONF.database.name}/#{CONF.environment}/#{CONF.migrate_from_release}"
MIGRATION_SOURCES << MigrationSource.new(svn_client, branch.conf.svn.root, special_migrations_path, "#{TMP}/#{CONF.special_migrations_dir}", CONF.database, SPECIAL_MIGRATION_PARSERS, :confirm_invalid => false, :confirm_valid => true)

puts
puts "Checking out from #{CONF.checkout_from_release} codebase #{branch.absolute_path}:"
MIGRATION_SOURCES.each do |src|
	if src.exists?
		src.download
		src.build
	end
end

total = MIGRATION_SOURCES.inject(0){ |memo,src| memo + src.number_of_checked_out_files }
puts "Checked out #{total} files."

MIGRATION_SOURCES.each do |src|
  src.confirm
end

######################
### BUILD MANIFEST ###
######################

MIGRATIONS = MIGRATION_SOURCES.collect(&:migrations).flatten

annotator = ManifestAnnotator.new CONF
annotator.add PositionAnnotation
annotator.add ReferenceAnnotation
annotator.add SingleLineRequisiteAnnotation
annotator.add MultiLineRequisiteAnnotation

MANIFEST = Manifest.new DATABASES, CONF, MIGRATIONS

MANIFEST.add_builder annotator
MANIFEST.add_builder ManifestOrderer.new
MANIFEST.add_builder ManifestPositionAnnotationsHandler.new

MANIFEST.build_from_scratch!

if CONF.save_manifest
  if MANIFEST.exists?
    CL::UI.confirm_or_exit "\nThe manifest file #{MANIFEST.filename} already exists.\nDo you wish to overwrite it? (yes/no) "
  end
  # delete the manifest upon success, unless configured otherwise
  CL::Signals.do_on_success{ MANIFEST.delete } unless CONF.keep_manifest
  MANIFEST.save
end

puts
puts 'The following table is the migration manifest.'
puts 'It describes which migrations are run in which order.'

if CONF.build_directly
  puts
  puts MANIFEST
else
  ManifestController.new(MANIFEST).edit
end

#######################
### BUILD MIGRATION ###
#######################

filename = "#{CONF.prefix}#{CONF.database.tag}-#{CONF.environment}-#{CONF.migrate_from_release}-to-#{CONF.migrate_to_release}-r#{CONF.first_revision}-r#{CONF.last_revision || 'HEAD'}#{CONF.suffix}.sql"

if File.exists? filename
  CL::UI.confirm_or_exit "\nThe migration file #{filename} already exists.\nDo you wish to overwrite it? (yes/no) "
end

builder = MigrationBuilder.new MANIFEST

title = TitleSection.new
config = ConfigurationSection.new
reqs = RequisitesSection.new
man = ManifestSection.new
spacer = SpacerSection.new
global_metrics = GlobalMetricsSection.new
migration_metrics = MigrationMetricsSection.new
migration_title = MigrationTitleSection.new
last_commit = LastCommitSection.new

# at start of file
builder.on :start, title, config, reqs, man, spacer, global_metrics

# before every migration
builder.on :start_migration, spacer, migration_title, migration_metrics

# after every migration
builder.on :end_migration, migration_metrics, migration_title

# at end of file
builder.on :end, spacer, global_metrics, last_commit

File.open(filename, 'w'){ |f| f.write builder.build }

puts
puts "Successfully built migration file #{filename}"

exit 0
