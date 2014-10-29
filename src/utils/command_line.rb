# Command line utilities.
module CL
end

# Auto-load libs.
[ :color, :options, :signals, :tmp, :ui ].each do |lib|
  require File.join(File.dirname(__FILE__), 'command_line', lib.to_s)
end
