class MigrationSource
  attr_accessor :migrations, :invalid_files, :number_of_checked_out_files, :parsers

  def initialize svn_client, root_url, remote_dir, local_dir, database, parsers = [], options = {}
    @svn_client, @root_url = svn_client, root_url
    @remote_dir, @local_dir, @database, @parsers = remote_dir, local_dir, database, parsers
    @confirm_invalid = options.key?(:confirm_invalid) ? options[:confirm_invalid] : true
    @confirm_valid = options[:confirm_valid]
    @migrations, @invalid_files = [], []
    @number_of_checked_out_files = 0
  end

  def download
    print "- checking out from #{@remote_dir}..."
    $stdout.flush
    @svn_client.checkout "#{@root_url}/#{@remote_dir}", @local_dir
    @number_of_checked_out_files = Dir.entries(@local_dir).reject{ |e| e.match /^\./ }.length
    puts " #{@number_of_checked_out_files} files"
  end

  def build
    Dir.entries(@local_dir).select{ |e| e.match /\.sql$/ }.each do |file|
      parsed = false
      @parsers.each do |parser|
        absolute_filename = "#{@local_dir}/#{file}"
        if !parsed and parser.match? absolute_filename
          migration = parser.build @database, absolute_filename
          @migrations << migration if parser.enabled? migration
          parsed = true
        end
      end
      @invalid_files << file unless parsed
    end
  end

  def confirm
    confirm_invalid; confirm_valid
  end

  def to_s
    @remote_dir.to_s
  end
  
  def exists?
    print "- checking that #{@remote_dir} exists..."
    $stdout.flush
    @svn_client.exists?("#{@root_url}/#{@remote_dir}").tap do |exists|
      puts(exists ? ' yes' : ' no')
    end
  end
  
  private

  def confirm_invalid
    return if !@confirm_invalid or @invalid_files.empty?
    puts("\nThe following migration files are badly named:\n" + @invalid_files.collect{ |f| "- #{f}" }.join("\n"))
    CL::UI.confirm_or_exit
  end

  def confirm_valid
    return if !@confirm_valid or @migrations.empty?
    puts(if @migrations.any?
      filenames = @migrations.collect{ |m| File.basename m.file }.sort{ |a,b|
        an = a.match(/\d+/).try(:[], 0).to_i
        bn = b.match(/\d+/).try(:[], 0).to_i
        (comp = an <=> bn) != 0 ? comp : a <=> b
      }
      "\nThe following migrations will be included:\n" + filenames.collect{ |f| "- #{@remote_dir}/#{f}" }.join("\n")
    else
      "\nNo contextual migrations were found in #{@remote_dir}."
    end)
    CL::UI.confirm_or_exit
  end
end

class Migration
  attr_accessor :database, :file, :manifest_tag, :position, :revision, :order
  attr_writer :description
  attr_reader :annotations

  def initialize h = {}
    @database, @file, @position = h[:database], h[:file], h[:position]
    @description, @manifest_tag = h[:description], h[:manifest_tag]
    @annotations = []
  end

  def contents configuration
    @contents ||= IO.read(file).tap do |s|
      s.gsub! /\$\{databaseServer\}/i, configuration.database.name
    end
  end

  def description
    return @description if @description
    return "manually added migration file: #{file}" unless database
    desc = "migration #{@revision || position.revision}"
    desc << "-#{@order || position.order}" if position.order and position.order >= 1
    desc << " of database #{database}"
  end

  def to_s
    "#{@database.tag} #{filename}"
  end

  def filename
    File.basename(file)
  end

  def to_manifest_s
    if @manifest_tag
      "#{manifest_tag} #{File.basename(file)}"
    elsif database
      "#{database.tag} #{File.basename(file)}"
    else
      "EXTERNAL #{file}"
    end
  end

  def <=> other
    position <=> other.position
  end
end

class MigrationPosition
  MAX_REVISION = 1000000
  attr_reader :filename, :database, :database_index
  attr_accessor :revision, :order

  def initialize configuration, h = {}
    @configuration = configuration
    @filename = h[:file] ? File.basename(h[:file]) : nil
    @database = h[:database]
    @database_index = Lotaris::Database.list_for_migration(configuration.database).index h[:database]
    @revision = h[:revision]
    @order = h[:order] || 0
  end

  def database= db
    @database = db
    @database_index = Lotaris::Database.list_for_migration(@configuration.database).index db
  end

  def <=> other
    rev = @revision || MAX_REVISION
    other_rev = other.revision || MAX_REVISION
    if (comp = rev <=> other_rev) != 0
      comp
    elsif (comp = @order <=> other.order) != 0
      comp
    elsif (comp = @database_index <=> other.database_index) != 0
      comp
    else
      an = @filename.to_s.match(/\d+/).try(:[], 0).to_i
      bn = other.filename.to_s.match(/\d+/).try(:[], 0).to_i
      (comp = an <=> bn) != 0 ? comp : @filename.to_s <=> other.filename.to_s
    end
  end

  def == other
    @revision == other.revision && @order == other.order && @database_index == other.database_index
  end

  def to_s
    "#{@database.tag.to_s.upcase} #{@revision}".tap do |s|
      s << "-#{@order}" if @order and @order >= 1
    end
  end
end

class StandardMigrationParser
  def initialize configuration
    @configuration = configuration
  end

  def match? file
    File.basename(file).match /^r\d+(\-\d+)?\.sql$/
  end

  def enabled? migration
    # revision cannot be checked here because of annotations
    true
  end

  def build database, file
    m = File.basename(file).match /^r(\d+)(?:\-(\d+))?\.sql$/
    pos = MigrationPosition.new(@configuration, :file => file, :database => database,
      :revision => m[1].to_i, :order => m[2].to_i )
    Migration.new :database => database, :position => pos, :file => file
  end
end

class StaticMigrationParser
  def initialize configuration, filename, enabled, &block
    @configuration, @filename, @enabled, @block = configuration, filename, enabled, block
  end

  def match? file
    File.basename(file) == @filename
  end

  def enabled? migration
    @enabled
  end

  def build database, file
    pos = MigrationPosition.new(@configuration, :file => file, :database => database )
    Migration.new( :database => database, :position => pos, :file => file ).tap do |mig|
      @block.call(mig) if @block
    end
  end
end

class SpecialMigrationParser
  def initialize configuration
    @configuration = configuration
  end

  def match? file
#    File.basename(file).match /^\d+\-[A-Z][A-Za-z0-9\_]*\.sql$/
     File.basename(file).match /.*\.sql/
  end

  def enabled? migration
    # revision cannot be checked here because of annotations
    true
  end

  def build database, file
    mig = Migration.new(
      :database => database, :file => file, :manifest_tag => :SPECIAL,
      :description => "special migration #{File.basename file}",
      :position => MigrationPosition.new(@configuration, :file => file, :database => database)
    )
  end
end
