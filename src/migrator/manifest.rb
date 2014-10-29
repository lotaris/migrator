require 'paint'

class Manifest
  @@column_width = 25
  attr_accessor :verbose
  attr_reader :migrations, :configuration, :invalid_files, :special_migration_files

  def self.column_width= w
    @@column_width = w
  end

  def initialize databases, configuration, migrations
    @databases, @configuration, @migrations = databases, configuration, migrations
    @builders = []
    @verbose = false
  end

  def add_builder builder
    @builders << builder
  end

  def to_s
    s = ' '
    s << ' ' * 5
    s << ' '
    s << ' ' * 3
    @databases.each do |db|
      s << sprintf("%-#{@@column_width}s", db.tag)
    end
    s << 'ADDITIONAL'
    @migrations.each_with_index do |migration,i|
      s << "\n "
      s << sprintf('%5s', (i + 1).to_s)
      s << '.   '
      line_done = false
      indentation = 10
      @databases.each do |db|
        if migration.database == db and migration.manifest_tag.nil?
          s << migration.filename
          line_done = true
          break
        else
          s << ' ' * @@column_width
          indentation += @@column_width
        end
      end
      unless line_done
        s << migration.filename if migration.database.blank? or migration.manifest_tag
      end
      next unless @verbose
      meta = migration_meta_information migration
      next if meta.blank?
      indentation += 2
      meta_spacer = ' ' * indentation
      s << "\n" + meta_spacer + Paint[meta.gsub("\n", "\n#{meta_spacer}"), :yellow]
    end
    s
  end

  def build_from_scratch!
    @builders.each{ |b| b.build self }
    @last_revision = @migrations.select{ |mig| mig.position.revision }.last.try(:position).try(:revision) || 'HEAD'
  end

  def save
    File.open(filename, 'w'){ |f| f.write to_txt } if @configuration.save_manifest
  end

  def delete
    FileUtils.rm_f filename
  end

  def exists?
    File.exists? filename
  end

  def validated?
    @validated
  end

  def validate
    @validated = true
  end

  def add_external_file file, line
    migration = Migration.new :file => file
    if line <= 1
      @migrations.insert 0, migration
    elsif line > @migrations.length
      @migrations.push migration
    else
      @migrations.insert((line - 1), migration)
    end
  end

  def remove range_start, range_end
    range_start = 1 if range_start < 1
    range_end = @migrations.length if range_end > @migrations.length
    if range_end < 1 or range_start > @migrations.length
      warn "Range is out of bounds; nothing to remove"
      false
    else
      deleted = @migrations.slice!((range_start - 1), (range_end - range_start + 1))
      puts "Removed the following migrations: #{deleted.collect(&:to_s).join ', '}"
      true
    end
  end

  def move range_start, range_end, line
    if line >= range_start and line <= range_end
      warn "Line is within range; nothing to move"
      false
    elsif range_end >= @migrations.length and line > @migrations.length
      warn "Range is already at end of list; nothing to move"
      false
    elsif range_start <= 1 and line <= 1
      warn "Range is already at start of list; nothing to move"
      false
    else
      range_start = 1 if range_start < 1
      range_end = @migrations.length if range_end > @migrations.length
      range = @migrations.slice!((range_start - 1), (range_end - range_start + 1))
      line -= range.length if line > range_end
      i = line - 1
      @migrations.insert i, range.pop while range.any?
      true
    end
  end

  def revision_range
    "#{@configuration.first_revision}:#{@last_revision}"
  end

  def filename
    "LotarisMigrationManifest_#{@configuration.database.tag}_#{@configuration.migrate_from_release}_to_#{@configuration.migrate_to_release}_#{revision_range}.txt"
  end

  private

  def migration_meta_information migration
    return nil if migration.annotations.blank?
    migration.annotations.collect(&:to_s).join("\n")
  end

  def to_txt
    @migrations.collect(&:to_manifest_s).join("\n") << "\n"
  end
end

class ManifestOrderer

  def build manifest
    manifest.migrations.sort!
  end
end

class ManifestController
  def initialize manifest
    @manifest = manifest
  end

  def edit
    while !@manifest.validated?
      puts
      puts @manifest
      puts
      puts 'Use the following commands to modify the manifest or continue:'
      puts '   add 10 FILE        insert FILE into manifest at line 10 (following lines are moved down)'
      puts '   move 20 30         move line 20 to line 30'
      puts '   move 10:20 30      move lines 10 to 20 to line 30'
      puts '   remove 10          remove line 10'
      puts '   remove 10:20       remove lines 10 to 20'
      print '   meta ('
      print(@manifest.verbose ? 'on) ' : 'off)')
      puts '         toggle migration meta information'
      puts '   build              build the migration file described by the manifest'
      puts '   quit               exit the script'
      puts
      execute_commands
    end
  end

  private

  COMMAND_ADD = /^add (\d+) (.+)$/
  COMMAND_MOVE = /^move (\d+)(?:\:(\d+))? (\d+)$/
  COMMAND_REMOVE = /^remove (\d+)(?:\:(\d+))?$/

  def execute_command com
    if com.blank?
      false
    elsif com == 'quit'
      CL::UI.cancel
    elsif com == 'build'
      @manifest.validate
    elsif com == 'meta'
      @manifest.verbose = !@manifest.verbose
      true
    elsif m = com.match(COMMAND_ADD)
      add_external_file_to_manifest m[1].to_i, m[2]
    elsif m = com.match(COMMAND_MOVE)
      move_migrations m[1].to_i, m[2].try(:to_i), m[3].to_i
    elsif m = com.match(COMMAND_REMOVE)
      remove_migrations m[1].to_i, m[2].try(:to_i)
    else
      warn "ERROR: unknown or invalid command #{com}"
      false
    end
  end

  def remove_migrations range_start, range_end
    range_end ||= range_start
    if range_end < range_start
      tmp = range_start; range_start = range_end; range_end = tmp
    end
    @manifest.remove range_start, range_end
  end

  def move_migrations range_start, range_end, line
    range_end ||= range_start
    if range_end < range_start
      tmp = range_start; range_start = range_end; range_end = tmp
    end
    @manifest.move range_start, range_end, line
  end

  def add_external_file_to_manifest line, file
    if !File.exists? file
      warn "ERROR: file #{file} does not exist"
      false
    elsif !File.file? file
      warn "ERROR: file #{file} is not a file"
      false
    elsif file.match(/\.sql$/).nil?
      warn "ERROR: file #{file} is not an SQL file"
      false
    elsif !File.readable? file
      warn "ERROR: file #{file} is not readable"
      false
    else
      @manifest.add_external_file file, line
      @manifest.save
      true
    end
  end

  def execute_commands
    message = 'Enter your command: '
    begin
      command = Readline.readline(message, true)
    end while !execute_command(command)
  end
end
