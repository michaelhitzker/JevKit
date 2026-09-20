import SwiftUI

struct ContentView: View {
    @State private var selection: Example? = .noul

    var body: some View {
        NavigationSplitView {
            List(Example.allCases, selection: $selection) { example in
                NavigationLink(value: example) {
                    Label(example.rawValue, systemImage: example.symbol)
                }
            }
            .navigationTitle("JevKit Examples")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            if let selection {
                ExampleDetail(example: selection)
                    .id(selection)
            } else {
                ContentUnavailableView("Choose an example", systemImage: "sidebar.left")
            }
        }
    }
}

private struct ExampleDetail: View {
    let example: Example
    @State private var model = ExampleModel()

    var body: some View {
        Form {
            Section {
                Text(example.explanation).font(.headline)
                Text("Jev supplies judgment. Swift decides what to do.")
                    .foregroundStyle(.secondary)
            }
            Section("Request") {
                Toggle("Use live API", isOn: $model.live)
                if model.live {
                    CredentialFields(mode: $model.credentialMode, directKey: $model.directKey, environmentVariable: $model.environmentVariable)
                } else {
                    Label("Offline fixture · no API key or network needed", systemImage: "airplane")
                    Text("Results are fixed demonstration data, regardless of the text below.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                TextEditor(text: $model.text)
                    .frame(minHeight: 110)
                    .accessibilityLabel("Issue text")
                if example != .score {
                    LabeledContent("Decision threshold", value: model.threshold.formatted(.percent))
                    Slider(value: $model.threshold, in: 0...1, step: 0.01)
                        .accessibilityLabel("Decision threshold")
                    Text("Used for the Noul yes decision and Choice confidence gate. Run again after changing it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(model.running)
            Section {
                HStack {
                    Button(model.live ? "Evaluate with Jev" : "Run demo") { model.run(example) }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.running || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.running {
                        ProgressView().controlSize(.small)
                        Button("Cancel") { model.cancel() }
                    }
                }
                if let status = model.status {
                    Label(status, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).textSelection(.enabled)
                }
            }
            ForEach(model.sections) { section in
                ResultSectionView(section: section)
            }
            if let metadata = model.metadata {
                Section("Last run") {
                    Text(metadata).font(.caption).foregroundStyle(.secondary)
                    Text("Results reflect the input and threshold at the time of the last run.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Swift usage") {
                ScrollView(.horizontal) {
                    Text(example.code)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(example.rawValue)
        .onDisappear { model.cancel() }
    }
}

private struct CredentialFields: View {
    @Binding var mode: CredentialMode
    @Binding var directKey: String
    @Binding var environmentVariable: String

    var body: some View {
        Picker("API-key source", selection: $mode) {
            ForEach(CredentialMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        switch mode {
        case .direct:
            SecureField("API key", text: $directKey)
                .autocorrectionDisabled()
            Text("Passed directly to JevConfiguration(apiKey:). Kept in memory for this screen only.")
        case .environment:
            TextField("Environment variable", text: $environmentVariable)
                .autocorrectionDisabled()
            Text("Set this variable in your private Xcode scheme’s Run environment. JEV_API_KEY and TYPESAFE_API_KEY are common choices.")
        case .infoPlist:
            Text("Add a JEV_API_KEY string entry to the app target’s Info settings. The SDK reads Bundle.main.infoDictionary.")
        case .plist:
            Text("Add JevSecrets.plist to the app’s resources with a JEV_API_KEY string entry. Keep the file out of source control.")
        }
        Text("Live runs send the issue to TypeSafe and may incur charges. Retries are disabled. Bundled keys are extractable; these options are for local development.")
            .font(.callout).foregroundStyle(.secondary)
    }
}

private struct ResultSectionView: View {
    let section: ResultSection

    var body: some View {
        Section(section.id) {
            Text(section.headline).font(.title2.bold())
            Text(section.detail).foregroundStyle(.secondary)
            ForEach(section.probabilities) { probability in
                VStack(alignment: .leading, spacing: 6) {
                    LabeledContent(probability.id, value: probability.value.formatted(.percent.precision(.fractionLength(1))))
                    ProgressView(value: probability.value)
                        .accessibilityLabel(probability.id)
                        .accessibilityValue(probability.value.formatted(.percent))
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    ContentView()
}
