import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var apiKey: String = ""
    @State private var isRevealed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if isRevealed {
                            TextField("sk-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Button {
                            isRevealed.toggle()
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Your key is stored locally on this device and never sent anywhere other than OpenAI.")
                }

                Section("Model") {
                    LabeledContent("Vision Model", value: "gpt-4o")
                        .foregroundStyle(.secondary)
                }

                Section("Calendar") {
                    LabeledContent("Calendar Name", value: "CalendarScan")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
