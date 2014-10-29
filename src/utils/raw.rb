
module Raw

  def self.awrap o
    o.kind_of?(Array) ? o : [ o ]
  end

  def self.hwrap o, key = :name
    o.kind_of?(Hash) ? o : { key => o }
  end

  def self.collect_with_index a, &block
    Array.new.tap do |r|
      a.each_with_index do |e,i|
        r << block.call(e, i)
      end
    end
  end
end
