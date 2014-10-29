class Object

  # An object is blank if it’s false, empty, or a whitespace string. For
  # example, “”, “ ”, nil, [], and {} are blank.
  #
  # This simplifies:
  #
  #   if !address.nil? && !address.empty?
  # ... to:
  #
  #   if !address.blank?
  def blank?
    nil? or (respond_to?(:empty?) and empty?)
  end

  # An object is present if it’s not blank.
  def present?
    !blank?
  end

  # Invokes the method identified by the symbol method, passing it any
  # arguments and/or the block specified, just like the regular Ruby Object#send does.
  #
  # Unlike that method however, a NoMethodError exception will not be
  # raised and nil will be returned instead, if the receiving object is
  # a nil object or NilClass.
  #
  # ==== Examples
  # Without try
  #   @person && @person.name
  # or
  #   @person ? @person.name : nil
  # With try
  #   @person.try(:name)
  #
  # try also accepts arguments and/or a block, for the method it is trying
  #   hash.try :[], key
  #   array.try(:collect){ |e| e.reverse }
  def try method, *args, &block
    nil? ? nil : send(method, *args, &block)
  end
end

class Array

  # Extracts options from a set of arguments. Removes and returns the
  # last element in the array if it’s a hash, otherwise returns a blank hash.
  def extract_options!
    if last.kind_of?(Hash) and last.extractable_options?
      pop
    else
      {}
    end
  end
end

class Hash

  # By default, only instances of Hash itself are extractable. Subclasses
  # of Hash may implement this method and return true to declare themselves
  # as extractable. If a Hash is extractable, Array#extract_options! pops it
  # from the Array when it is the last element of the Array.
  def extractable_options?
    instance_of?(Hash)
  end
end
