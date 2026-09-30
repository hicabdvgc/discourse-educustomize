# frozen_string_literal: true

RSpec.describe DiscourseEducustomize::AgentConfiguration do
  fab!(:model, :fake_model)
  let(:document) do
    JSON.parse(File.read(File.expand_path("../fixtures/agent_configuration.json", __dir__)))
  end
  let(:configuration) { described_class.new(document) }

  before do
    SiteSetting.educustomize_model_ids = model.id.to_s
    SiteSetting.educustomize_tool_names = "Time"
  end

  describe "#errors" do
    it "accepts the complete Bloc and a standalone assistant" do
      expect(configuration.errors).to be_empty
      document["agents"] = [document["agents"].last]
      document["root"] = document["agents"].first["key"]
      expect(described_class.new(document).errors).to be_empty
    end

    it "identifies unsupported versions, unknown fields, and invalid field types" do
      invalid_documents = [
        document.merge("schema_version" => 2),
        document.merge("credentials" => {}),
        document.deep_dup.tap { |copy| copy["agents"].first["enabled"] = "true" },
        document.deep_dup.tap { |copy| copy["agents"].first["skills"].first["extra"] = true },
        document.deep_dup.tap { |copy| copy["agents"].first["temperature"] = 3 },
        document.deep_dup.tap { |copy| copy["agents"].first.delete("tools") },
      ]
      invalid_documents.each { |invalid| expect(described_class.new(invalid).errors).to be_present }
    end

    it "reports schema failures as complete English sentences with field locations and constraints" do
      document["schema_version"] = 2
      document["credentials"] = {}
      document["agents"].first["temperature"] = "invalid"
      document["agents"].first["top_p"] = 0
      document["agents"].first.delete("tools")

      I18n.with_locale(:en) do
        expect(configuration.errors).to contain_exactly(
          "The value at /schema_version must be 1.",
          "The configuration format does not support the field at /credentials.",
          "The value at /agents/0/temperature does not match the expected JSON type (number, null).",
          "The number at /agents/0/top_p must be greater than 0.",
          "The object at /agents/0 is missing the following required fields: tools.",
        )
      end
    end

    it "localizes schema failures in Chinese while preserving field locations" do
      document["agents"] = []
      document["schema_version"] = 2
      document["credentials"] = {}

      I18n.with_locale(:zh_CN) do
        expect(configuration.errors).to contain_exactly(
          "/schema_version 处的值必须为 1。",
          "此配置格式不支持 /credentials 处的字段。",
          "/agents 处的列表至少需要包含 1 个项目。",
        )
      end
    end

    it "rejects dangling references, duplicate keys, self references, nested Delegates, and unrelated agents" do
      invalid_documents = [
        document.merge("root" => "missing"),
        document.deep_dup.tap { |copy| copy["agents"].last["key"] = "tutor" },
        document.deep_dup.tap { |copy| copy["agents"].first["delegates"] = %w[dais critic] },
        document.deep_dup.tap { |copy| copy["agents"].last["delegates"] = ["dais"] },
        document.deep_dup.tap { |copy| copy["agents"].first["delegates"] = ["tutor"] },
        document.deep_dup.tap { |copy| copy["agents"].first["delegates"] = %w[foreign critic] },
      ]
      invalid_documents.each { |invalid| expect(described_class.new(invalid).errors).to be_present }
    end

    it "rejects tools outside the current allowlist and overlong composed instructions" do
      document["agents"].first["tools"] = ["Search"]
      expect(configuration.errors.join).to include("Search")
      document["agents"].first["tools"] = ["Time"]
      document["agents"].first["system_prompt"] = "x" * 100_000
      expect(configuration.errors).to be_present
    end
  end

  describe "#preview" do
    it "maps a unique model and proposes unused names without changing prompt content or the source" do
      Fabricate(:ai_agent, name: document["agents"].first["name"])
      original = document.deep_dup
      preview = configuration.preview

      expect(preview[:model_mappings]).to eq(
        "dais" => model.id,
        "tutor" => model.id,
        "critic" => model.id,
      )
      expect(preview[:document]["agents"].first["name"]).to eq(
        original["agents"].first["name"] +
          I18n.t("educustomize.configuration.copy_suffix", number: 2),
      )
      expect(preview[:document]["agents"].first["system_prompt"]).to eq(
        original["agents"].first["system_prompt"],
      )
      expect(document).to eq(original)
    end

    it "requires explicit selection when a model is missing or ambiguous" do
      duplicate = Fabricate(:fake_model)
      SiteSetting.educustomize_model_ids = [model.id, duplicate.id].join("|")
      expect(configuration.preview[:model_mappings].values).to eq([nil, nil, nil])
      SiteSetting.educustomize_model_ids = ""
      expect(configuration.preview[:model_mappings].values).to eq([nil, nil, nil])
    end
  end

  describe "#mapping_errors" do
    it "accepts authorized replacement models and rejects missing, unapproved, extra, or mistyped mappings" do
      mappings = document["agents"].to_h { |agent| [agent["key"], model.id] }
      expect(configuration.mapping_errors(mappings)).to be_empty
      invalid_mappings = [
        nil,
        {},
        mappings.merge("dais" => -1),
        mappings.merge("dais" => model.id.to_s),
        mappings.merge("foreign" => model.id),
      ]
      invalid_mappings.each do |invalid|
        expect(configuration.mapping_errors(invalid)).to be_present
      end
    end
  end
end
