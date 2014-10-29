require 'paint'

class ManifestAnnotator

  def initialize configuration
    @configuration = configuration
    @parsers = []
    @errors = {}
  end

  def build manifest
    parse manifest.migrations
    confirm
  end

  def add parser
    @parsers << parser
  end

  def parse migrations
    @errors.clear
    return if @parsers.blank?
    migrations.each{ |mig| parse_migration mig }
  end

  def confirm
    return if @errors.blank?
    msg = "\n#{Paint['The following annotations could not be parsed:', :red, :bold]}"
    @errors.each_pair do |k,v|
      v.each do |err|
        msg << "\n"
        msg << Paint["- #{k.database.tag.to_s.upcase} #{File.basename k.file}: ", :yellow]
        msg << Paint[err, :red]
      end
    end
    puts msg
    CL::UI.confirm_or_exit
  end

  private

  def parse_migration migration
    contents = migration.contents @configuration
    while m = contents.match(/^-- @([^\n]+)$/i)
      begin
        parse_annotation migration, m[1]
      rescue StandardError => e
        (@errors[migration] ||= []) << e.message
      end
      contents = m.post_match
    end
  end

  def parse_annotation migration, annotation
    parsed = false
    @parsers.each do |parser|
      if parser.matches? annotation
        a = build_annotation parser, annotation, migration
        migration.annotations << a if a
        parsed = true
        break
      end
    end
    return if parsed
    raise "invalid #{annotation}"
  end

  def build_annotation parser, annotation, migration
    args = [ @configuration, annotation, migration ]
    parser.respond_to?(:build) ? parser.build(*args) : parser.new(*args)
  end
end

class RequisiteAnnotation
end

class SingleLineRequisiteAnnotation < RequisiteAnnotation
  REGEXP = /^(pre|post)\s+(.+)$/i

  def self.matches? annotation
    annotation.match REGEXP
  end

  attr_reader :type, :requisite

  def initialize configuration, annotation, migration
    m = annotation.match REGEXP
    @type, @requisite = m[1].downcase.to_sym, m[2]
  end

  def to_s
    "@#{@type} #{@requisite}"
  end
end

class MultiLineRequisiteAnnotation < RequisiteAnnotation
  START_REGEXP = /^(pre|post)\-start/i
  END_REGEXP = /^(pre|post)\-end/i

  def self.matches? annotation
    annotation.match(START_REGEXP) or annotation.match(END_REGEXP)
  end

  def self.build configuration, annotation, migration
    return false if annotation.match END_REGEXP
    m = annotation.match START_REGEXP
    type = m[1]

    switch = "@annotation_multiline_requisite_#{type}".to_sym
    if migration.instance_variable_get switch
      raise "there can only be one #{type}-start annotation per migration"
    end
    migration.instance_variable_set switch, true

    regexp = /@#{type}\-start(.+?)@#{type}\-end/m
    content = migration.contents(configuration).match(regexp).try :[], 1

    unless content
      raise "could not find a matching #{type}-end annotation for #{type}-start annotation"
    end

    content = "\n#{content.strip}".gsub(/\n\s*\-\- /m, "\n").gsub(/\n\s*\-\-/, "\n").rstrip
    return MultiLineRequisiteAnnotation.new type, content
  end

  attr_reader :type, :requisite

  def initialize type, requisite
    @type, @requisite = type.downcase.to_sym, requisite
  end

  def to_s
    "@#{@type} #{@requisite}"
  end
end

class ReferenceAnnotation
  REGEXP = /^references\s+(\d+)\s*$/i

  def self.matches? annotation
    annotation.match REGEXP
  end

  attr_reader :revision

  def initialize configuration, annotation, migration
    m = annotation.match REGEXP
    @revision = m[1].to_i
  end

  def to_s
    "@references #{@revision}"
  end
end

class PositionAnnotation
  REGEXP = /^(at|before|after)\s+([A-Za-z0-9\_\-]+)\s+(\d+)(?:-(\d+))?\s*$/i

  def self.matches? annotation
    annotation.match REGEXP
  end

  attr_reader :relation, :position

  def initialize configuration, annotation, migration
    m = annotation.match REGEXP
    @relation = m[1].downcase.to_sym
    database = Lotaris::Database.find m[2].downcase
    raise "unknown database '#{m[2]}' in #{@relation} annotation" if database.blank?
    revision = m[3].to_i
    order = m[4].to_i
    @position = MigrationPosition.new configuration, :database => database, :revision => revision, :order => order
  end

  def to_s
    "@#{@relation} #{@position}"
  end
end

class ManifestPositionAnnotationsHandler

  def build manifest

    holders = manifest.migrations.collect{ |mig| ManifestMigrationHolder.new :migration => mig }

    final_holders = []
    positioned_holders = []
    holders.each do |h|
      a = h.migration.annotations.select{ |a| a.kind_of? PositionAnnotation }.last

      if a.blank?
        final_holders << h
        next
      end

      target = final_holders.find{ |t| t.position == a.position }
      target ||= holders.find{ |t| t.position == a.position }

      if target.blank?
        target = ManifestMigrationHolder.new :position => a.position
        final_holders << target
      end
      
      if a.relation == :after
        target.next << h
      elsif a.relation == :before
        target.previous << h
      elsif a.relation == :at
        target.current << h
      else
        CL::UI.terminate "unknown annotation #{a} in #{h.migration}"
      end
    end

    conf = manifest.configuration
    first, last = conf.first_revision, conf.last_revision
    final_holders.delete_if do |fh|
      rev = fh.position.revision
      rev.present? and rev >= 0 and ((first.present? and rev < first) or (last.present? and rev > last))
    end

    final_holders.sort!

    while final_holders.any?{ |fh| fh.next.any? or fh.current.any? or fh.previous.any? }
      current_holders = []
      final_holders.each do |h|
        current_holders.concat h.previous.sort if h.previous.any?
        tmp = []
        tmp << h
        tmp.concat h.current if h.current.any?
        current_holders.concat tmp.sort if tmp.any?
        current_holders.concat h.next.sort if h.next.any?
        h.previous.clear
        h.current.clear
        h.next.clear
      end
      final_holders = current_holders
    end

    migrations = final_holders.collect{ |h| h.migration }.compact
    manifest.migrations.clear.concat migrations
  end
end

class ManifestMigrationHolder
  attr_accessor :previous, :current, :next
  attr_reader :migration, :position

  def initialize options = {}
    @migration = options[:migration]
    @position = options[:position] || @migration.position
    @previous, @current, @next = [], [], []
  end

  def <=> other
    position <=> other.position
  end
end
