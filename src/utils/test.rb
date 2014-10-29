require 'paint'

class PrimitiveTestSuite
  DEFAULT_PREFIX = '> '
  DEFAULT_SUFFIX = '     '

  def initialize name
    @name = name
    @tests = []
    @name_column = 0
    @prefix = DEFAULT_PREFIX.dup
    @suffix = DEFAULT_SUFFIX.dup
  end
  
  def run
    puts "Testing #{@name}..."
    successful = true
    @total_time = 0
    @tests.each do |t|
      unless run_test t[:name], t[:block]
        successful = false
        break
      end
    end
    report successful
  end

  def test name, &block
    @tests << { :name => name, :block => block }
    @name_column = name.length if name.length > @name_column
  end

  private

  def report successful
    puts
    puts "Total Time: #{@total_time}s."
    puts
    if successful
      puts important(good("Test suite #{@name} ran without errors."))
    else
      puts important(bad("Test suite #{@name} failed."))
    end
    puts
  end

  def run_test name, block
    print "#{@prefix}#{name}#{@suffix}".ljust name_column_length
    $stdout.flush
    start = Time.now
    begin
      if block.call self
        benchmark!(start)
        puts success
        true
      else
        benchmark!(start)
        puts failure
        false
      end
    rescue Exception => e
      puts failure
      puts "#{' ' * @prefix.length}   #{notice(e)}"
      false
    end
  end

  def success
    "[   #{good(:OK)}   ]"
  end

  def important s
    Paint[s, :bold]
  end

  def failure
    "[ #{bad(:FAILED)} ]"
  end

  def good s
    Paint[s, :green]
  end

  def bad s
    Paint[s, :red]
  end

  def notice s
    Paint[s, :yellow]
  end

  def benchmark! start
    time = (Time.now - start).round
    @total_time += time
    print "#{time}s".ljust 5
  end

  def name_column_length
    @prefix.length + @name_column + @suffix.length
  end
end
