class RealWorldValidator
  include ::ErrorModule

  VALIDATORS = [
    Validators::Parenthood,
    Validators::Relationships,
    Validators::Actions
  ]

  def initialize(value)
    @value = value
  end

  def validate!
    VALIDATORS
      .map { |validator| validator.new(value) }
      .each(&:validate!)
  end
end
