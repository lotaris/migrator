require 'readline'
require File.join(File.dirname(__FILE__), 'options')

module CL

  # Utilities related to user input on the command line.
  class UI

    def self.register_options optparser
      optparser.on '-y', '--yes', 'do not ask for confirmation' do
        self.yes = true
      end
    end

    extend CL::Options::Group
    register_command_line_option CL::Options::Option.new(:short => :y, :long => :yes, :description => 'answer yes to all confirmations'){ self.yes = true }

    # Sets the yes flag. The yes flag indicates that all confirmations
    # should be answered positively. It can be retrieved with UI.yes.
    def self.yes= yes
      @@yes = yes
    end

    # If present, all confirmations should be answered positively.
    def self.yes
      @@yes
    end

    # Exits the script successfully. If <tt>message</tt> is present,
    # it is printed before exiting.
    def self.cancel message = "\nCanceled by user."
      puts message if message
      exit 0
    end

    # Exits the script with a failed status (1). If <tt>message</tt>
    # is present, it is printed on stderr before exiting.
    def self.terminate message = 'An unexpected error occurred.'
      puts "ERROR: #{message}" if message
      exit 1
    end

    # Prompts the user to confirm with <tt>message</tt>. Repeats until
    # the user gives a choice that returns a non-nil value when passed
    # to UI.parse_boolean. The choice is returned.
    #
    # Immediately returns true if UI.yes is present.
    def self.confirm message = "\nDo you wish to proceed? (yes/no) ", *args
      options = args.extract_options!
      return true if @@yes && (!options.key?(:yes) || options[:yes])
      default_choice = options[:choice]
      return default_choice unless default_choice.nil?

      self.configure_readline
      self.configure_readline_completion

      choice = nil
      while choice.blank?
        choice = self.readline message
        return nil if choice.nil?
        choice = parse_boolean choice
      end
      choice
    end

    # Prompts the user to confirm with UI.confirm and exits with
    # UI.cancel if the resulting choice is not positive.
    #
    # Immediately returns true if UI.yes is present.
    def self.confirm_or_exit message = "\nDo you wish to proceed? (yes/no) "
      self.cancel unless confirm message
    end

    def self.ask message, pattern = /[^\s]/, *args
      options = args.extract_options!
      default_choice = options[:choice].to_s
      return default_choice if default_choice.match pattern
      raise ArgumentError, "CL::UI.ask requires a Regexp as second argument." unless pattern.kind_of?(Regexp)

      self.configure_readline
      self.configure_readline_completion

      choice = nil
      while choice.blank?
        choice = self.readline message
        return nil if choice.nil?
        choice.strip! unless options.key?(:strip) && !options[:strip]
        choice = nil unless choice.match pattern
      end
      choice
    end

    def self.ask_or_exit message, pattern = /[^\s]/, *args
      self.ask(message, pattern, *args).tap do |choice|
        self.cancel if choice.nil?
      end
    end

    def self.choose_from message, *args
      options = args.extract_options!
      choices = args.collect &:to_s
      default_choice = options[:choice].to_s
      return default_choice if choices.include? default_choice
      return nil if choices.blank?

      choices.collect!(&:downcase) unless options[:case_sensitive]

      self.configure_readline
      args = choices + [ options ]
      self.configure_readline_completion *args

      choice = nil
      while !choices.include?(choice) && !(choice.blank? && options[:allow_blank])
        choice = self.readline message
        return nil if choice.nil?
        choice.strip! unless options.key?(:strip) && !options[:strip]
      end
      choice
    end

    def self.choose_from_or_exit message, *args
      choose_from(message, *args).tap do |choice|
        self.cancel if choice.nil?
      end
    end

    # Returns a boolean parsed from user input <tt>b</tt>. True is
    # returned if input matches any of <tt>y, yes, 1</tt>. False is
    # returned if input matches any of <tt>n, no, 0</tt>. Otherwise
    # <tt>nil_value</tt> is returned.
    def self.parse_boolean b, nil_value = nil
      case b
      when /^y|yes|1$/i; true
      when /^n|no|0$/i; false
      else; nil_value
      end
    end

    private

    def self.readline message, history = true
      begin
        Readline.readline message, history
      rescue Interrupt
        self.cancel
      end
    end

    def self.configure_readline
      begin
        Readline.emacs_editing_mode
        Readline.completion_append_character = ' '
      rescue NotImplementedError
        @@readline_completion_append_character = false
      end
    end

    def self.configure_readline_completion *args
      options = args.extract_options!
      choices = args
      if choices.blank?
        Readline.completion_proc = proc{ nil }
        return
      end
      choices.collect!{ |s| "#{s} " } unless @@readline_completion_append_character
      if options[:case_sensitive]
        Readline.completion_proc = proc{ |s| choices.grep /^#{Regexp.escape(s)}/ }
      else
        Readline.completion_proc = proc{ |s| choices.grep /^#{Regexp.escape(s)}/i }
      end
    end

    @@yes = false
    @@readline_completion_append_character = true
  end
end
