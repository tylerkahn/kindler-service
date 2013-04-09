module Utilities 
  module_function

  def symbolize_keys(h)
    h.keys.each do |key|
      h[(key.to_sym rescue key) || key] = h.delete(key)
    end
    h
  end
end
