module CL

  # Utilities to execute code when the script exits.
  class Signals

    # Traps script signals. Blocks registered with Signals.do_on_term
    # and Signals.do_on_success will be executed when the script exits
    # depending on the exit status.
    def self.trap
      TERM_STATUSES.each{ |sig| Signal.trap(sig){ @@do_on_term.each{ |block| block.call } } }
      SUCCESS_STATUSES.each{ |sig| Signal.trap(sig){ @@do_on_success.each{ |block| block.call } } }
    end

    # Blocks registered with this method will be executed if the
    # script exits with any of the following statuses: <tt>QUIT,
    # TERM, KILL, INT</tt>.
    #
    # Signals.trap must be called for this to be activated.
    #
    # ==== Examples
    #   CL::Signals.do_on_success{ FileUtils.rm_f tmp_file }
    #   CL::Signals.trap
    def self.do_on_term &block
      @@do_on_term << block if block
    end

    # Blocks registered with this method will be executed if the
    # script exits successfully with status 0.
    #
    # Signals.trap must be called for this to be activated.
    #
    # ==== Examples
    #   CL::Signals.do_on_success{ FileUtils.rm_f tmp_file }
    #   CL::Signals.trap
    def self.do_on_success &block
      @@do_on_success << block if block
    end

    private

    # List of exit statuses considered a termination.
    TERM_STATUSES = [ "QUIT", "TERM", "KILL", "INT" ]
    # List of exit statuses considered successful.
    SUCCESS_STATUSES = [ 0 ]
    @@do_on_term = []
    @@do_on_success = []
  end
end
