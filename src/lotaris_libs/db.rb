
module Lotaris

  # A Lotaris database.
  #
  # To register all default databases:
  #   Lotaris::Database.register_defaults!
  #
  # This class extends CL::Options::Group and provides the following options:
  # * <tt>--db--no-shared</tt> - Do not migrate shared databases (e.g. SLIB). Will
  #   automatically call Database.use_shared= with <tt>false</tt> as argument if consumed.
  class Database

    extend CL::Options::Group
    self.command_line_options_group_name = :db
    self.register_command_line_option CL::Options::Option.new(:long => :'no-shared', :description => 'do not migrate shared databases (e.g. SLIB)'){ self.use_shared = false }

    # The tag identifying the database (e.g. LIS, BGS, RESDATA).
    attr_reader :tag
    # The name of the database.
    attr_reader :name
    # Whether the database is shared (e.g. SLIB). Shared databases are
    # included in every migration by default.
    attr_reader :shared
    # The repository where this database's migrations are stored (lme if not specified).
    attr_reader :repository
    # Returns the directory in which migrations are stored for this database,
    # relative to the codebase directory.
    attr_reader :migrations_path

    # Returns the database with the given tag or name (case-insensitive),
    # or nil if none matches.
    def self.find search
      @@databases.find{ |db| [ :tag, :name ].find{ |a| db.send(a).to_s.downcase == search.to_s.downcase } }
    end

    # Returns the list of databases to migrate for the given database.
    # By default, this is a list containing all shared databases plus
    # the one given as argument.
    #
    # Shared databases can be omitted by calling #use_shared= beforehand.
    def self.list_for_migration database_to_migrate
      @@databases.select{ |db| @@use_shared ? db.shared : false } << database_to_migrate
    end

    # Sets whether shared databases should be included in the list of
    # databases returned by #list_for_migration.
    def self.use_shared= value
      @@use_shared = value
    end

    # Register all default databases.
    #
    # They are configured in the <tt>lotaris.yml</tt> resource under
    # <tt>/db/defaults</tt>. A new database is instantiated for each
    # of the hashes in this list.
    def self.register_defaults!
      svn_conf = Lotaris.conf :svn
      Lotaris.conf(:db, :defaults).each{ |conf| Database.new svn_conf, conf }
    end

    # Registers and returns a new database.
    #
    # If a database with the same tag already exists, an error is printed
    # on stderr and the script exits with status 2. Every new database is
    # automatically registered on instantiation.
    #
    # ==== Options
    # * <tt>:name => symbol or string</tt> - *mandatory* - The name of the database.
    # * <tt>:shared => boolean</tt> - Whether the database is shared (see #shared).
    # * <tt>:tag => symbol or string</tt> - The tag identifying this database.
    # * <tt>:migrations_path => string</tt> - The directory in which migrations are
    #   stored for the database, relative to the codebase directory.
    #
    # ==== Migration Path Options
    # These options are used to build the migrations path if the
    # <tt>:migrations_path</tt> option is not given. See #build_migrations_path.
    # * <tt>:base_dir => symbol or string</tt> - The base directory in which the
    #   server using this database is stored, relative to the codebase directory
    #   (e.g. <tt>ThirdParty</tt>). There is no base directory by default.
    # * <tt>:server_name => symbol or string</tt> - The name of the server using
    #   the database (e.g. <tt>LotarisReportingServer</tt>). This is the same as
    #   the name of the database by default (given in the <tt>:name</tt> option).
    # * <tt>:migrations_project_type => symbol or string</tt> - The type of server
    #   project in which the migrations directory is stored for the database (e.g.
    #   <tt>resources</tt>). This is <tt>ear</tt> by default.
    # * <tt>:migrations_dir => symbol or string</tt> - The name of the directory in
    #   which migrations are stored for the database (e.g. <tt>migration-data</tt>).
    #   This is <tt>migration</tt> by default.
    def initialize svn_conf, *args
      options = args.extract_options!
      @repository = options[:repository] || :lme
      @conf = Lotaris::Subversion.repository_conf(@repository).migrations
      @name, @shared = options[:name], options[:shared]
      @tag, @migrations_path = build_tag(options), build_migrations_path(options)
      if self.class.find @tag
        warn "ERROR: database #{@tag} is already registered."; exit 2
      end
      @@databases << self
    end

    # Returns the name of this database.
    def to_s
      @name
    end

    private

    @@databases = []
    @@use_shared = true

    # Returns the tag identifying this database. If the <tt>:tag</tt> option
    # is given, its value is returned.
    #
    # Otherwise, the following algorithm is used to build the tag from the name:
    # * remove <tt>"Lotaris"</tt> from the start of the name;
    # * remove <tt>"Server"</tt> from the end of the name;
    # * take the first two letters of the remaining string in uppercase;
    # * append <tt>"S"</tt>.
    #
    # ==== Examples
    #   build_tag :name => "LotarisAnExampleServer", :tag => "EXS"
    #   # => "EXS"
    #
    #   build_tag :name => "LotarisSampleServer"
    #   # => "SAS"
    def build_tag options
      return options[:tag] if options[:tag].present?
      "#{@name.sub(/^Lotaris/, '').sub(/Server$/, '')[0, 2].upcase}S"
    end

    # Returns the directory in which migrations are stored for this database,
    # relative to the codebase directory. If the <tt>:migrations_path</tt>
    # option is given, its value is returned.
    #
    # Otherwise, the following algorithm is used to build the path:
    # * take the path template in the <tt>lotaris.yml</tt> resource under
    #   <tt>/svn/lme/migrations/path</tt>;
    # * replace every <tt>%{NAME}</tt> token with the result of #server_name;
    # * replace every <tt>%{PROJECT_TYPE}</tt> token with the result of #project_name;
    # * replace every <tt>%{DIR}</tt> token with the result of #migrations_dir;
    # * if the <tt>:base_dir</tt> option is given, prepend its value to the result.
    #
    # ==== Examples
    # See #initialize.
    def build_migrations_path options
      return options[:migrations_path] if options[:migrations_path].present?
      path = @conf.path.dup
      path.gsub! /\%\{NAME\}/, server_name(options)
      path.gsub! /\%\{PROJECT_TYPE\}/, project_type(options)
      path.gsub! /\%\{DIR\}/, migrations_dir(options)
      options[:base_dir].present? ? "#{options[:base_dir]}/#{path}" : path
    end

    # Returns the name of the server using this database. This is either
    # the name given in the <tt>:server_name</tt> option or the same name
    # as the database (given in the <tt>:name</tt> option).
    def server_name options
      options[:server_name] || @name
    end

    # Returns the project type (e.g. ear, resources) in which migration files
    # are stored for this database. This is either the type given in the
    # <tt>:migrations_project_type</tt> option or the default type of the
    # <tt>lotaris.yml</tt> resource found under <tt>/svn/lme/migrations/default_project_type</tt>.
    def project_type options
      options[:migrations_project_type] || @conf.default_project_type
    end

    # Returns the name of the migrations directory for this database.
    # This is either the directory given in the <tt>:migrations_dir</tt> option
    # or the default directory of the <tt>lotaris.yml</tt> resource found
    # under <tt>/svn/lme/migrations/default_dir</tt>.
    def migrations_dir options
      options[:migrations_dir] || @conf.default_dir
    end
  end
end
