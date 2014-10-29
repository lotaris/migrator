
module Lotaris

  class ConfigurationError < StandardError
  end

  class SubversionConfiguration
    attr_reader :branches, :paths, :migrations, :root, :name, :symfony

    def self.names
      raise ConfigurationError, "Expected ':svn' to be a hash in lotaris.yml." if !Lotaris.conf(:svn).kind_of?(Hash)
      Lotaris.conf(:svn).keys.tap{ |names| names.delete :default }
    end
    
    def initialize name
      raise ConfigurationError, "Expected ':svn' to be a hash in lotaris.yml." if !Lotaris.conf(:svn).kind_of?(Hash)
      raise ConfigurationError, "Expected ':svn -> :default' to be a hash in lotaris.yml." if !Lotaris.conf(:svn, :default).kind_of?(Hash)
      raise ArgumentError, "Subversion configuration name 'default' is reserved." if name.to_s == 'default'

      default = Lotaris.conf :svn, :default
      base = Lotaris.conf :svn, name.to_s.to_sym
      raise ArgumentError, "Unknown subversion configuration '#{name}'." if base.blank?

      @name = name
      @root = base[:root]
      raise ConfigurationError, "Expected ':svn -> :#{name} -> :root' to define the root URL of the repository." if @root.blank?

      # Define the option to propose the operations around symfony libraries
      @symfony = (base[:symfony] ? base[:symfony] : false)

      @paths = {}
      (default[:paths] || {}).merge(base[:paths] || {}).each_pair do |path_name, path|
        @paths[path_name.to_s] = path
      end

      @branches = {}
      (default[:branches] || {}).merge(base[:branches] || {}).each_pair do |type, conf|
        @branches[type.to_s] = SubversionBranchConfiguration.new self, type, conf
      end

      opts = (default[:migrations] || {}).merge(base[:migrations] || {})
      @migrations = SubversionMigrationsConfiguration.new self, opts
    end

    def path name
      @paths[name.to_s]
    end

    def branch name
      @branches[name.to_s]
    end
    
    def makable_branches
      @branches.reject{ |name,branch| branch.permanent? }
    end
  end

  class SubversionMigrationsConfiguration
    attr_reader :path, :contextuals_path, :correctives_path, :default_project_type, :default_dir

    def initialize svn, options
      @path = options[:path].to_s
      @contextuals_path, @correctives_path = options[:contextuals_path].to_s, options[:correctives_path].to_s
      @default_project_type, @default_dir = options[:default_project_type].to_s, options[:default_dir].to_s
    end
  end

  class SubversionBranchConfiguration
    attr_reader :type, :svn, :default_target, :default_source, :name_regexp, :examples, :naming, :maven
    
    def initialize svn, type, options
      @svn = svn
      @type = type.to_s.to_sym
      @path = options[:path].to_s
      @human = options[:human]
      @name_regexp = Regexp.new options[:name]
      @permanent = options[:permanent]
      @examples = options[:examples]
      @naming = SubversionBranchNamingConfiguration.new self, options[:naming] if options[:naming]
      @default_target = SubversionBranchDescriptor.new self, options[:target] if options[:target]
      @default_source = SubversionBranchDescriptor.new self, options[:source] if options[:source]
      @maven = SubversionBranchMavenConfiguration.new self, options[:maven] if options[:maven]
    end

    def process_name name, &block
      @naming ? @naming.process(name, &block) : name
    end

    def name_select_block
      lambda{ |name| name.match @name_regexp }
    end

    def permanent?
      @permanent
    end

    def permanent_identifier
      @permanent ? @type.to_s.upcase : nil
    end

    def human_type
      @human || @type.to_s
    end

    def path identifier = nil
      @svn.path(@path).dup.tap do |p|
        p.gsub!(/\%\{NAME\}/, identifier) if identifier
      end
    end

    def common_path
      path.sub(/\%\{NAME\}.*$/, '').chomp '/'
    end

    def absolute_common_path
      Lotaris.process_path "#{@svn.root}/#{common_path}"
    end

    def base_path identifier = nil
      starting_path = @svn.path(@path).dup
      last_path = starting_path
      current_path = starting_path
      begin
        last_path = current_path
        basename = File.basename current_path
        if basename.match /\%\{NAME\}/
          return current_path.tap{ |path| path.gsub!(/\%\{NAME\}/, identifier) if identifier }
        end
        current_path = File.dirname current_path
      end while current_path != last_path
      raise "Could not find %{NAME} token in branch path #{starting_path}."
    end

    def absolute_base_path identifier = nil
      Lotaris.process_path "#{@svn.root}/#{base_path identifier}"
    end
  end

  class SubversionBranchMavenConfiguration
    attr_reader :version

    def initialize branch, options
      @branch = branch
      @version = options[:version]
    end
  end

  class SubversionBranchNamingConfiguration
    attr_reader :type

    def initialize branch, options
      @type = options[:type] || :string
      @filter = Regexp.new(options[:filter]) if options[:filter]
      @format = options[:format]
      @prefix = options[:prefix]
      @suffix = options[:suffix]
    end

    def process name, &block
      name = name.to_s.dup
      name = name.gsub(@filter, '') if @filter
      name = name.to_i.to_s if @type == :integer
      name = block.call(name).to_s if block
      name = sprintf(@format, name) if @format
      "#{@prefix}#{name}#{@suffix}"
    end

    def integer?
      @type == :integer
    end
  end

  class SubversionBranchDescriptor
    attr_reader :type, :selector

    def initialize branch, options
      @parent_branch = branch
      if options.kind_of?(String) || options.kind_of?(Symbol)
        @simple = true
        @type = options.to_s
      elsif options.kind_of?(Hash)
        @simple = false
        @type = options[:type] || branch.type
        @selector = options[:selector]
        @human = options[:human]
      else
        raise ConfigurationError, "Unknown branch descriptor type #{options.class.name}."
      end
    end

    def next?
      @selector == :next && branch.naming.integer?
    end

    def branch
      @parent_branch.svn.branch @type
    end

    def simple?
      @simple
    end

    def human
      @human || "the #{@type}"
    end
  end
end
