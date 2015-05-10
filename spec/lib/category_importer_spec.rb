require 'rails_helper'

describe CategoryImporter do
  let(:invalid_content) { Rails.root.join('spec/support/fixtures/invalid_category.csv').read }
  let(:invalid_parent) { Rails.root.join('spec/support/fixtures/invalid_parent_category.csv').read }
  let(:valid_content) { Rails.root.join('spec/support/fixtures/valid_category.csv').read }
  let(:existing_content) { Rails.root.join('spec/support/fixtures/existing_category.csv').read }

  subject(:importer) { CategoryImporter.new(content) }

  describe '#valid?' do
    context 'when the category content is invalid' do
      let(:content) { invalid_content }

      it { is_expected.not_to be_valid }
    end

    context 'when the content is valid' do
      let(:content) { valid_content }

      it { is_expected.to be_valid }
    end
  end

  describe '#errors' do
    context 'when the category content is not valid' do
      let(:content) { invalid_content }

      errors = ["Line 2: Name can't be blank for Category"]

      its(:errors) { is_expected.to eq(errors) }
    end

    context 'when the parent category is not valid' do
      let(:content) { invalid_parent }

      errors = ["Line 2: Name can't be blank for Category"]

      its(:errors) { is_expected.to eq(errors) }
    end
  end

  describe '#import' do
    context 'with all the required fields to create a category' do
      let(:content) { valid_content }

      it 'creates a category' do
        expect { importer.import }.to change(Category, :count).by(4)
      end

      describe 'the category' do
        before { importer.import }

        subject { Category.second }

        its(:name) { is_expected.to eq 'Disaster Response' }
        its(:taxonomy_id) { is_expected.to eq '101-01' }
        its('parent.taxonomy_id') { is_expected.to eq '101' }
      end
    end

    context 'when one of the fields required for a category is blank' do
      let(:content) { invalid_content }

      it 'does not create a category' do
        expect { importer.import }.to change(Category, :count).by(0)
      end
    end

    context 'when the category already exists' do
      before do
        DatabaseCleaner.clean_with(:truncation)
        create(:category)
      end

      let(:content) { existing_content }

      it 'does not create a new category' do
        expect { importer.import }.to_not change(Category, :count)
      end

      it 'generates error' do
        expect(importer.errors).
          to eq ['Line 2: Taxonomy id has already been taken']
      end
    end
  end

  describe '.check_and_import_file' do
    it 'calls FileChecker' do
      path = Rails.root.join('spec/support/fixtures/valid_category.csv')

      file = double('FileChecker')
      allow(file).to receive(:validate).and_return true

      expect(FileChecker).to receive(:new).
        with(path, CategoryImporter.required_headers).and_return(file)

      CategoryImporter.check_and_import_file(path)
    end

    context 'with valid data' do
      it 'creates a category' do
        expect do
          path = Rails.root.join('spec/support/fixtures/valid_category.csv')
          CategoryImporter.check_and_import_file(path)
        end.to change(Category, :count)
      end
    end

    context 'with invalid data' do
      it 'does not create a category' do
        allow_any_instance_of(IO).to receive(:puts)
        expect do
          path = Rails.root.join('spec/support/fixtures/invalid_category.csv')
          CategoryImporter.check_and_import_file(path)
        end.not_to change(Category, :count)
      end
    end
  end

  describe '.required_headers' do
    it 'matches required headers in Wiki' do
      expect(CategoryImporter.required_headers).
        to eq %w(taxonomy_id name parent_id parent_name)
    end
  end
end
