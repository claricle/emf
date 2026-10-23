# frozen_string_literal: true

module DiagnosticContractSupport
  def diagnostic_parse(backend, bytes)
    previous = ENV.fetch("EMF_BACKEND", nil)
    ENV["EMF_BACKEND"] = backend
    expect(Emf::Backend).to receive(:selected).and_wrap_original do |original|
      selected = original.call
      if backend == "ruby"
        expect(selected.name).to eq("Emf::Backend::Ruby")
      else
        expect(selected).to be_a(Emf::Native::Adapter)
        expect(Emf::Emr::Parser).not_to receive(:call)
        expect(selected).to receive(:parse_emf).and_call_original
      end
      selected
    end
    Emf.parse(bytes)
  ensure
    ENV["EMF_BACKEND"] = previous
  end
end
