require 'paint'

module CL

  # Utilities to color output on the command line.
  #
  # The current implementation is an interface to the <tt>paint</tt> gem.
  #
  # ==== Examples
  #   puts CL::Color.bold 'Hello World!'
  #   puts "[ #{CL::Color.ok :OK} ]"
  #
  # All the methods can be chained.
  #   puts CL::Color.bold(CL::Color.underline('Very important instructions.'))
  class Color
    
    # Returns text in bold.
    def self.bold s
      Paint[s, :bold]
    end

    # Returns underlined text.
    def self.underline s
      Paint[s, :underline]
    end

    # Returns text in green.
    def self.green s
      Paint[s, :green]
    end

    # Returns text in red.
    def self.red s
      Paint[s, :red]
    end

    # Returns text in yellow.
    def self.yellow s
      Paint[s, :yellow]
    end

    # Final success notice in bold green.
    def self.final_success s
      bold success(s)
    end

    # Aliases.
    class << self
      # Program name in help (bold).
      alias_method :program_name, :bold
      # Help section (bold).
      alias_method :help_section, :bold
      # Reference to a help section (underline).
      alias_method :help_section_ref, :underline
      # Okay result (green).
      alias_method :ok, :green
      # Success (green).
      alias_method :success, :green
      # Failed result (red).
      alias_method :failed, :red
      # Failure (red).
      alias_method :failure, :red
      # Warning (yellow).
      alias_method :warning, :yellow
    end
  end
end
