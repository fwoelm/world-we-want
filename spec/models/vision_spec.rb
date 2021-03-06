require 'rails_helper'

RSpec.describe Vision, type: :model do

  subject(:vision) { build(:vision) }

  it "has a valid factory" do
    is_expected.to be_valid
  end

  describe "accessors" do
    it {
      is_expected.to define_enum_for(:color).
        with([:red, :pink, :purple, :deep_purple, :indigo, :blue, :light_blue, :cyan, :teal, :green, :light_green, :lime, :yellow, :amber, :orange, :deep_orange, :brown, :gray, :blue_gray])
    }
    it { is_expected.to have_one(:identity).dependent(true) }
  end

  describe "associations" do
    it { is_expected.to have_attached_file(:image) }
  end

  describe "validations" do
    it { is_expected.to validate_attachment_content_type(:image).
        allowing('image/png', 'image/gif', 'image/jpg').
        rejecting('text/plain', 'text/xml') }
    it { is_expected.to validate_attachment_size(:image).less_than(5.megabytes) }
  end

  describe "callbacks" do
    context "before_create" do
      after { vision.save }
      it { expect(vision).to receive(:set_ID_token_expiration) }
    end

    context "after_create" do
      before { vision.save }

      it "has set id_token" do
        expect(vision.id_token).not_to be_nil
      end
    end
  end

  describe ".find_next_vision" do

    let!(:vision_id_zero) { create(:vision) }
    let!(:vision_id_one) { create(:vision) }
    let!(:vision_id_two) { create(:vision) }

    it ".find_next_vision(2) returns vision with ID 1" do
      next_vision = Vision.find_next_vision(vision_id_two.id)
      expect(next_vision).to be_a Vision
      expect(next_vision.id).to be vision_id_one.id
    end

    it ".find_next_vision(1) returns vision with ID 0" do
      next_vision = Vision.find_next_vision(vision_id_one.id)
      expect(next_vision).to be_a Vision
      expect(next_vision.id).to be vision_id_zero.id
    end

    it ".find_next_vision(0) returns nil" do
      next_vision = Vision.find_next_vision(vision_id_zero.id)
      expect(next_vision).not_to be_a Vision
      expect(next_vision).to be nil
    end

  end

  describe "#clean_paperclip_errors" do

    context "when the file is not an image" do

      before do
        vision.image = File.new("#{Rails.root}/spec/support/fixtures/sample.txt")
      end

      it "shows only one error" do
        expect(vision).not_to be_valid
        expect(vision.errors.count).to be 1
      end

    end
  end

  describe "#set_ID_token_expiration" do

    it "sets the expiration to 24 hours from now" do
      vision.send(:set_ID_token_expiration)
      expect(vision.id_token_expiration).to be_within(1.second).of(Time.zone.now + 24.hours)
    end
  end

  describe "#new_identity_path" do

    before do
      vision.id = 5
      vision.id_token = "523BE6ONM"
    end

    it "contains the vision ID: 5" do
      expect(vision.new_identity_path).to include("id=5")
    end

    it "contains the vision token: 523BE6ONM" do
      expect(vision.new_identity_path).to include("token=523BE6ONM")
    end

  end

  describe ".find_random_vision" do

    before do
      Vision.delete_all
    end

    context "when there is only one vision" do

      let!(:vision) {create(:vision)}

      it "returns nil" do
        expect(Vision.count).to be 1

        random_vision = Vision.find_random_vision(vision.id)
        expect(random_vision).not_to be_a Vision
        expect(random_vision).to be nil
      end
    end

    context "when there are two visions" do

      let!(:vision_id_zero) { create(:vision) }
      let!(:vision_id_one) { create(:vision) }

      it ".find_random_vision(0) returns vision with ID 1" do
        expect(Vision.count).to be 2

        random_vision = Vision.find_random_vision(vision_id_zero.id)
        expect(random_vision).to be_a Vision
        expect(random_vision.id).to be vision_id_one.id
      end

      it ".find_random_vision(1) returns vision with ID 0" do
        expect(Vision.count).to be 2

        random_vision = Vision.find_random_vision(vision_id_one.id)
        expect(random_vision).to be_a Vision
        expect(random_vision.id).to be vision_id_zero.id
      end
    end

  end

  describe ".find_previous_vision" do

    let!(:vision_id_zero) { create(:vision) }
    let!(:vision_id_one) { create(:vision) }
    let!(:vision_id_two) { create(:vision) }

    it ".find_previous_vision(0) returns vision with ID 1" do
      previous_vision = Vision.find_previous_vision(vision_id_zero.id)
      expect(previous_vision).to be_a Vision
      expect(previous_vision.id).to be vision_id_one.id
    end

    it ".find_previous_vision(1) returns vision with ID 2" do
      previous_vision = Vision.find_previous_vision(vision_id_one.id)
      expect(previous_vision).to be_a Vision
      expect(previous_vision.id).to be vision_id_two.id
    end

    it ".find_previous_vision(2) returns nil" do
      previous_vision = Vision.find_previous_vision(vision_id_two.id)
      expect(previous_vision).not_to be_a Vision
      expect(previous_vision).to be nil
    end

  end

  describe "#verify_id_token" do

    before { vision.save }

    let(:verified_vision) { vision.verify_id_token(token) }
    let(:token) { vision.id_token }

    context "when token has expired" do

      before do
        vision.id_token_expiration = Time.zone.now - 25.hours
      end

      it "returns nil" do
        expect(verified_vision).to eq Vision.none
      end
    end

    context "when token and ID do not match" do

      let(:token) { vision.id_token + "abcabc" }

      it "returns nil" do
        expect(verified_vision).to eq Vision.none
      end
    end

    context "when token and ID match" do
      it "returns vision of corresponding ID" do
        expect(verified_vision).to be vision
      end
    end

  end
end
