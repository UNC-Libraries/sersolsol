require './lib/setup'

module Ingestable
  def loaded?
    libs = self.libs
    if libs.include?(:aalload) or libs.include?(:hsl) or libs.include?(:law)
      return true
    else
      return false
    end
  end
end
