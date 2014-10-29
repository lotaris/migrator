require File.expand_path('../extensions', File.dirname(__FILE__))
require File.join(File.dirname(__FILE__), 'color')
require 'optparse'

module CL

  class ImprovedOptionParser < OptionParser
    attr_accessor :footer

    def initialize *args
      options = args.extract_options!

      @hash = options[:hash]
      @footer = options[:footer]
      @examples = options[:examples]

      width = options[:width] || 32
      indent = options[:indent] || (' ' * 2)
      super nil, width, indent

      @banner = options[:banner].kind_of?(Hash) ? summary_banner_section(options[:banner]) : options[:banner]
    end

    def summary_banner_section *args
      options = args.extract_options!
      %|#{summary_program_name} #{options[:description]}

#{CL::Color.help_section :USAGE}
#{@summary_indent}#{summary_program_name} #{options[:usage]}

#{CL::Color.help_section :OPTIONS}
|
    end

    def summary_examples_section
      return nil unless @examples
      String.new("\n#{CL::Color.help_section :EXAMPLES}").tap do |s|
        @examples.each do |example|
          s << "\n#{@summary_indent}#{summary_program_name} #{example}"
        end
      end
    end

    def program_name
      @program_name || File.basename($0)
    end

    def summary_program_name
      CL::Color.program_name program_name
    end

    def parse_or_exit!
      begin
        parse!
      rescue Exception => err
        unless err.kind_of?(SystemExit)
          puts
          Kernel.warn Paint["Error: #{err.message}", :yellow]
          puts
          puts self
          exit 2
        else
          exit err.status
        end
      end
    end

    def to_s
      "#{super}#{summary_examples_section}#{@footer}"
    end

    def hash_on name, *opts
      raise ArgumentError, "Options hash wasn't given at construction." unless @hash && @hash.kind_of?(Hash)
      on(*opts){ |val| @hash[name] = val }
    end

    def register_help_and_usage!
      self.on('-h', '--help', 'display this help'){ puts self; exit 0 }
      self.on('-u', '--usage', 'display this help'){ puts self; exit 0 }
    end
  end

  # Utilities to parse options given at the command line.
  module Options

    # The representation of a script with command line arguments. This
    # utilizes Parser, Option and Group to easily define and parse
    # options. It also supports printing an usage notice for the script.
    #
    # ==== Examples
    #   filename = File.basename __FILE__
    #   action = 'does some stuff'
    #   script = CL::Options::Script.new filename, action, :examples => [
    #     '-f', '-o VALUE', '-f --opt VALUE'
    #   ]
    #
    #   feature1_opt = CL::Options::Option.new(
    #                   :description => 'activate feature 1',
    #                   :short => :f){ activate_feature1 }
    #
    #   option1_opt = CL::Options::Option.new(
    #                  :description => 'set option 1',
    #                  :short => :o, :long => :opt, :arity => 1){ |arg|
    #                    OPTION1 = arg }
    #
    #   script.register feature1_opt, option1_opt
    #
    #   script.consume ARGV
    class Script
      
      # Constructs a command line script. See class definition.
      #
      # ==== Arguments
      # * <tt>name</tt> - The name of the script. Should be the filename
      #   as returned by <tt>File.basename(__FILE__)</tt>.
      # * <tt>action</tt> - A short description of the purpose of the
      #   script. Should be a simple sentence without capitalization or
      #   punctuation, e.g. <tt>"does some stuff"</tt>.
      #
      # ==== Options
      # * <tt>:examples => array</tt> - A list of examples to display in
      #   the usage notice. The name of the script will be prepended to
      #   each example.
      def initialize name, action, *args
        options = args.extract_options!
        @name, @action, @parser = name, action, Parser.new
        @examples = options[:examples]
      end

      # Consumes all the arguments in <tt>args</tt> until <tt>-</tt> or
      # <tt>--</tt> is encountered.
      #
      # Each argument is consumed by the first registered option that matches
      # the argument as defined by Option#matches?. Consumption is done by
      # calling Option#consume.
      #
      # If no option matches, an error is printed on stderr and the script
      # exits with status 1.
      def consume args = ARGV
        @parser.consume args
      end

      # Registers the specified options or option groups. (See Parser#register.)
      #
      # If any two options registered through this method have the same short
      # form or the same long form, an error is printed on stderr and the
      # script exits with status 1.
      def register *args
        @parser.register *args
      end

      # Adds the default help and usage options.
      # If #consume is called after this method and any of
      # <tt>-h, --help, -u, --usage</tt> are present in the arguments,
      # the result of #usage will be printed and the script will exit with
      # status 0.
      def register_help_and_usage!
        usage_block = lambda{ puts usage; exit 0 }
        desc = 'shows this help and exits'
        @parser.register Option.new(:description => desc, :short => :h, :long => :help, &usage_block)
        @parser.register Option.new(:description => desc, :short => :u, :long => :usage, &usage_block)
      end

      # Returns the usage notice for this script.
      def usage
        String.new.tap do |s|
          s << "#{@name} #{@action}."
          s << "\n"
          s << "\nUsage:"
          s << "\n  #{@name} [OPTION]..."
          s << "\n\n#{usage_options}" if @parser.options.present?
          s << "\n\n#{usage_examples}" if @examples.present?
        end
      end

      private

      # Returns the options portion of the usage notice.
      #
      # The description of each option contains its forms (see Option#forms)
      # and description (see Option#description).
      def usage_options
        label_width = @parser.options.collect{ |opt| opt.forms.length }.sort.last + 3
        String.new.tap do |s|
          s << "Options:"
          @parser.options.each do |opt|
            s << "\n  "
            s << sprintf("%-#{label_width}s", opt.forms)
            s << opt.description
          end
        end
      end

      # Returns the examples portion of the usage notice.
      def usage_examples
        String.new.tap do |s|
          s << "Examples:"
          @examples.each do |ex|
            s << "\n  #{@name} #{ex}"
          end
        end
      end
    end

    # A parser that can read and handle command line arguments.
    class Parser

      # The list of registered options for this parser.
      attr_reader :options

      # Returns a new parser with no registered options.
      def initialize
        @options, @short_option_names, @long_option_names = [], [], []
      end

      # Consumes all the arguments in <tt>args</tt> until <tt>-</tt> or
      # <tt>--</tt> is encountered.
      #
      # Each argument is consumed by the first registered option that matches
      # the argument as defined by Option#matches?. Consumption is done by
      # calling Option#consume.
      #
      # If no option matches, an error is printed on stderr and the script
      # exits with status 1.
      def consume args = ARGV
        while args.any?
          arg = args.shift
          break if arg.match /^(-|--)$/
          consume_argument arg, args
        end
      end

      # Registers the specified options or option groups.
      #
      # If any two options registered through this method have the same short
      # form or the same long form, an error is printed on stderr and the
      # script exits with status 1.
      def register *args
        args.each do |arg|
          if arg.kind_of?(Option)
            register_option arg
          elsif arg.respond_to? :command_line_options
            register_group arg
          else
            warn "WARNING: option class #{arg.class} cannot be registered in options parser."
          end
        end
      end

      private

      # Registers all the options in <tt>group</tt> returned by
      # Group#command_line_options.
      def register_group group
        group.command_line_options.each{ |opt| register_option opt }
      end

      # Registers <tt>option</tt> and ensures that its short and
      # long form are unique.
      def register_option option
        register_short_option_name option.short if option.short.present?
        register_long_option_name option.long if option.long.present?
        @options << option
      end

      # Prints an error on stderr and exits with status 1 if the
      # given option short form was already encountered.
      def register_short_option_name name
        if @short_option_names.include? name
          warn "ERROR: short option #{name} already registered."; exit 1
        end
        @short_option_names << name
      end

      # Prints an error on stderr and exits with status 1 if the
      # given option long form was already encountered.
      def register_long_option_name name
        if @long_option_names.include? name
          warn "ERROR: long option #{name} already registered."; exit 1
        end
        @long_option_names << name
      end

      # Consumes the given command line argument.
      #
      # This method iterates over
      # the list of arguments until an option that matches <tt>text</tt> is
      # found (see Option#matches?). If it finds one, it calls Option#consume
      # with <tt>args</tt> as argument. If no matching option is found, an
      # error is printed on stderr and the script exits with status 1.
      def consume_argument text, args
        if matching_option = @options.find{ |opt| opt.matches? text }
          matching_option.consume args
        else
          warn "ERROR: unknown option #{text}."; exit 1
        end
      end
    end

    # Mixin to provide command line options for a specific class/instance.
    # Objects including this mixin can be registered with Script#register or
    # Parser#register.
    #
    # ==== Examples
    #   class MyModule
    #     extend CL::Options::Group
    #   end
    #
    #   opt = CL::Options::Option.new(:description => 'do some stuff',
    #          :short => :o, :long => :opt, :arity => 1){ |arg|
    #     do_some_stuff_with(arg)
    #   end
    #
    #   MyModule.register_command_line_option opt
    module Group

      # Adds the given option to this group. All registered options can be
      # retrieved with #command_line_options.
      #
      # If a group name was set with #command_line_options_group_name=, it is set
      # for the option with Option#group=.
      def register_command_line_option option
        (@command_line_options ||= []) << option
        option.group = @command_line_options_group_name if @command_line_options_group_name.present?
      end

      # Returns a list of all the options in this group, which may be empty.
      def command_line_options
        @command_line_options || []
      end

      # Sets the name of this group. The group is set for future registered options
      # (see #register_command_line_option). Calling this method does not set the
      # group of previously registered options.
      def command_line_options_group_name= name
        @command_line_options_group_name = name
      end
    end

    # Command line option. An option can have a short form (e.g. <tt>-o</tt>) and
    # long form (e.g. <tt>--opt</tt>). It can take a number of arguments (e.g.
    # <tt>--opt ARG1 ARG2</tt>).
    #
    # ==== Examples
    #   CL::Options::Option.new(:description => 'do some stuff',
    #    :short => :o, :long => :opt, :arity => 1){ |arg|
    #     do_some_stuff_with(arg)
    #   end
    class Option

      # A description of this option for a usage notice.
      # This should be a simple lowercase sentence, such as
      # <tt>"do some stuff"</tt>.
      attr_reader :description
      
      # Returns a new option. If a block is given, it is executed when calling #consume.
      #
      # ==== Options
      # * <tt>:description => string</tt> - A full description of the option (should
      #   indicate the purpose and default value).
      # * <tt>:short => symbol or string</tt> - This is the short form of the option
      #   without the hyphen, e.g. <tt>o</tt>. It must be exactly one letter or digit.
      #   It is optional if there is a <tt>:long</tt> option.
      # * <tt>:long => symbol or string</tt> - This is the long form of the option
      #   without the hyphens, e.g. <tt>opt, mod-config</tt>. It must start with a
      #   letter or digit and be formed only of letters and digits optionally
      #   separated with hyphens. It is optional if there is a <tt>:short</tt> option.
      # * <tt>:arity => integer</tt> - This is the number of arguments the option takes
      #   (0 by default).
      def initialize *args, &block

        options = args.extract_options!
        @arity, @description, @block = options[:arity].to_i, options[:description], block

        if options[:short].present?
          @short = options[:short].to_s
          raise "Short option #{@short} should be one leter or digit." unless @short.match /^[a-zA-Z0-9]$/
        end

        if options[:long].present?
          @long = options[:group].present? ? "#{options[:group]}-#{options[:long]}" : options[:long].to_s
          raise "Long options #{@long} should be letters and digits separated by hyphens." unless @long.match /^[a-zA-Z0-9](\-?[a-zA-Z0-9])*$/
        end

        raise "Command line option must have either a :short or :long argument" if @short.blank? and @long.blank?
      end

      # Returns the short form of this option, e.g. <tt>-o</tt>, if any.
      def short
        @short.present? ? "-#{@short}" : nil
      end

      # Returns the long form of this option, e.g. <tt>--opt</tt>, if any.
      def long
        @long.present? ? "--#{@long}" : nil
      end

      # Returns true if the short or long form of this option match the given argument.
      def matches? arg
        (@short.present? and arg == short) or (@long.present? and arg == long)
      end

      # Executes the block given at construction. If an arity greater than zero was
      # specified at construction, that number of elements are shifted from <tt>args</tt>
      # and passed to the block as arguments.
      def consume args
        block_args = (@arity >= 1 ? args.slice!(0, @arity) : [])
        @block.call *block_args if @block
      end

      # Prefixes the long form of this option with <tt>name</tt>.
      #
      # ==== Examples
      #   option.long
      #   # => "--opt"
      #
      #   option.group = 'my-module'
      #   option.long
      #   # => "--my-module-opt"
      def group= name
        @long = "#{name}-#{@long}" if @long.present?
      end

      # Returns a description of the short and long form of this option.
      #
      # ==== Examples
      #   option_with_short_form.to_s
      #   # => "-o"
      #
      #   option_with_short_and_long_form.to_s
      #   # => "-o, --opt"
      #
      #   option_with_arity.to_s
      #   # => "-o, --opt OPT"
      def forms
        String.new.tap do |s|
          # short and long forms separated by a comma
          s << [ short, long ].compact.join(', ')
          if @arity == 1
            # if there is only one argument, it takes the name of the
            # long form in uppercase, or defaults to ARG
            s << ' ' << (@long.try(:upcase) || 'ARG')
          elsif @arity >= 2
            # if there are several arguments, they take the names
            # ARG1, ARG2, etc
            @arity.times{ |i| s << " ARG#{i + 1}" }
          end
        end
      end
    end
  end
end
