import SwiftUI

struct ContentView: View {
    let settings: ExampleSettings
    @State private var showingSettings = false
    @State private var selection: Example? = .noul

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Explore the SDK") {
                    ForEach(Example.allCases) { example in
                        NavigationLink(value: example) {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(example.title)
                                    Text(example.rawValue)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                            } icon: {
                                Image(systemName: example.symbol)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { showingSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("JevKit")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        } detail: {
            if let selection {
                ExampleDetail(example: selection, settings: settings, showingSettings: $showingSettings).id(selection)
            } else {
                ContentUnavailableView("Choose an example", systemImage: "sidebar.left",
                                       description: Text("Explore yes/no decisions, choices, and scores."))
            }
        }
        .sheet(isPresented: $showingSettings) {
            ExampleSettingsView(settings: settings)
        }
    }
}

private struct ExampleSettingsView: View {
    @Bindable var settings: ExampleSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("API key") {
                    SecureField("API key", text: $settings.apiKey)
                        .autocorrectionDisabled()
                    Text("Applies to every example. You can edit or replace your key here. Changes take effect on the next run.")
                        .foregroundStyle(.secondary)
                    Text("Your key is saved securely in Keychain and restored when you reopen the app. Clear the field to remove the saved key.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let error = settings.persistenceError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("Retry saving key") { settings.persistKey() }
                    }
                }
                Section {
                    Text("Running an example sends the issue to TypeSafe and may incur charges.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 500, minHeight: 400, idealHeight: 520)
    }
}

private struct ExampleDetail: View {
    let example: Example
    @Binding var showingSettings: Bool
    @State private var model: ExampleModel

    init(example: Example, settings: ExampleSettings, showingSettings: Binding<Bool>) {
        self.example = example
        _showingSettings = showingSettings
        _model = State(initialValue: ExampleModel(settings: settings))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ExampleHeader(example: example)
                RequestView(example: example, model: model, showingSettings: $showingSettings)
                ResultsView(sections: model.sections, metadata: model.metadata, running: model.running)
                Divider()
                DisclosureGroup("View Swift code") {
                    ScrollView(.horizontal) {
                        Text(example.code)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.subheadline)
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(example.title)
        .onDisappear { model.cancel() }
    }
}

private struct ExampleHeader: View {
    let example: Example

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(example.rawValue).font(.subheadline.weight(.medium)).foregroundStyle(.tint)
            Text(example.question).font(.largeTitle.bold())
            Text(example.explanation).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RequestView: View {
    let example: Example
    @Bindable var model: ExampleModel
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1. Try an issue").font(.title3.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text("Issue description").font(.subheadline.weight(.medium))
                TextEditor(text: $model.text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 110)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                    .accessibilityLabel("Issue description")
                    .disabled(model.running)
            }
            if example != .score {
                DisclosureGroup("Decision settings · \(model.threshold.formatted(.percent)) threshold") {
                    VStack(alignment: .leading, spacing: 8) {
                        Slider(value: $model.threshold, in: 0...1, step: 0.01)
                            .accessibilityLabel("Decision threshold")
                        Text(example == .noul
                             ? "Label as a bug when the yes probability reaches this threshold. Run again to apply changes."
                             : "Use this threshold to accept a choice with enough confidence. Run again to apply changes.")
                            .font(.caption).foregroundStyle(.secondary)
                        if example == .assessment {
                            Text("Also applies to the bug decision. Escalation uses a separate, fixed 95% confidence rule.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.subheadline)
                .disabled(model.running)
            }
            HStack(spacing: 12) {
                Button { model.run(example) } label: {
                    Label("Run example", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.running || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if model.running {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { model.cancel() }
                }
            }
            if let status = model.status {
                Label(status, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                if model.needsAPIKey {
                    Button("Open Settings") { showingSettings = true }
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct ResultsView: View {
    let sections: [ResultSection]
    let metadata: String?
    let running: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2. See the decision").font(.title3.bold())
            if sections.isEmpty {
                Label(running ? "Evaluating the issue…" : "Run the example to see the result here.",
                      systemImage: "sparkle.magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(sections) { section in
                    ResultSectionView(section: section)
                }
                if let metadata {
                    Text("Last run: \(metadata). Results use the input and settings from that run.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ResultSectionView: View {
    let section: ResultSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.id).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(section.headline).font(.title2.bold())
            Text(section.detail).font(.callout).foregroundStyle(.secondary)
            if !section.probabilities.isEmpty {
                DisclosureGroup("Probability breakdown") {
                    VStack(spacing: 14) {
                        ForEach(section.probabilities) { probability in
                            VStack(alignment: .leading, spacing: 6) {
                                LabeledContent(probability.id, value: probability.value.formatted(.percent.precision(.fractionLength(1))))
                                ProgressView(value: probability.value)
                                    .accessibilityLabel(probability.id)
                                    .accessibilityValue(probability.value.formatted(.percent))
                            }
                        }
                    }
                    .padding(.top, 12)
                }
                .font(.subheadline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView(settings: ExampleSettings())
}
