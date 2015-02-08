class Validation
  def initialize(value, errors = [])
    @value = value
    @errors = errors
  end

  attr_reader :value, :errors

  def with(validator)
    (new_value, validation_errors) = validator.validate(value)
    accumulated_errors = errors + Array(validation_errors)

    return Valid.new(new_value) if accumulated_errors.empty?
    Error.new(new_value, accumulated_errors)
  end

  class Valid < Validation
    def valid?
      true
    end
  end

  class Error < Validation
    def valid?
      false
    end
  end
end

class BiggerThan42
  def self.validate(value)
    if value < 42
      [value, ["#{value} is not bigger than 42"]]
    else
      value
    end
  end
end

class BiggerThan84
  def self.validate(value)
    if value < 84
      [value, ["#{value} is not bigger than 84"]]
    else
      value
    end
  end
end
