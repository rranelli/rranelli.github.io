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

  delegate :errors, :valid?, to: :validation

  def validate!
    validation.tap do |validation|
      fail SomeError, validation.errors unless validation.valid?
    end
  end

  private

  def validation
    seed = Validation.new(value)
    VALIDATORS.reduce(seed, &:reduce)
  end
end
