# frozen_string_literal: true

module Emf
  module Native
    class Unavailable < Error; end

    def self.backend
      raise Unavailable, "native backend is not installed"
    end
  end
end
