require 'rspec'
require_relative 'validator'

RSpec.describe Validation do
  subject(:validation) { described_class.new(value) }

  let(:value) { 43 }

  describe '#with' do
    subject(:with) { validation.with(validator) }

    let(:validator) { BiggerThan42 }

    it { is_expected.to be_a(Validation::Valid) }
    it { is_expected.to be_valid }

    context 'when the value is not valid' do
      let(:value) { 41 }

      it { is_expected.to be_a(Validation::Error) }
      it { is_expected.not_to be_valid }
      it { expect(with.errors.count).to eq(1) }

      context 'when chaining validations' do
        subject(:chained_with) { with.with(validator) }

        let(:validator) { BiggerThan84 }

        it { is_expected.to be_a(Validation::Error) }
        it { is_expected.not_to be_valid }

        it 'accumulates all errors' do
          expect(chained_with.errors.count).to eq(2)
        end
      end

      context 'using Array#reduce' do
        let(:validators) { [BiggerThan84, BiggerThan42] }

        subject(:reduced) { validators.reduce(validation, &:with) }

        it { is_expected.to be_a(Validation::Error) }
        it { is_expected.not_to be_valid }

        it 'accumulates all errors' do
          expect(reduced.errors.count).to eq(2)
        end
      end
    end
  end
end
