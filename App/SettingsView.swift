import SwiftUI

struct SettingsView: View {
    @Environment(RepoListViewModel.self) private var viewModel
    @State private var editedSettings: AppSettings = AppSettings()
    @State private var isDirty = false

    var body: some View {
        Form {
            Section("Scanning") {
                TextField("Scan Root", text: $editedSettings.scanRoot)
                    .onChange(of: editedSettings.scanRoot) { isDirty = true }

                Stepper("Max Depth: \(editedSettings.scanDepth)", value: $editedSettings.scanDepth, in: 1...8)
                    .onChange(of: editedSettings.scanDepth) { isDirty = true }

                Stepper("Day Range: \(editedSettings.dayRange)", value: $editedSettings.dayRange, in: 7...365, step: 7)
                    .onChange(of: editedSettings.dayRange) { isDirty = true }

                Stepper("Display Count: \(editedSettings.displayCount)", value: $editedSettings.displayCount, in: 5...50, step: 5)
                    .onChange(of: editedSettings.displayCount) { isDirty = true }
            }

            Section("Author Emails") {
                ForEach(editedSettings.authorEmails.indices, id: \.self) { index in
                    HStack {
                        TextField("Email", text: $editedSettings.authorEmails[index])
                            .onChange(of: editedSettings.authorEmails[index]) { isDirty = true }
                        Button(role: .destructive) {
                            editedSettings.authorEmails.remove(at: index)
                            isDirty = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Email") {
                    editedSettings.authorEmails.append("")
                    isDirty = true
                }
            }

            Section("Appearance") {
                HStack {
                    Text("Chart Opacity: \(Int(editedSettings.windowOpacity * 100))%")
                    Slider(value: $editedSettings.windowOpacity, in: 0.3...1.0, step: 0.05)
                        .onChange(of: editedSettings.windowOpacity) { isDirty = true }
                }

                Toggle("Show in Menu Bar", isOn: $editedSettings.showMenuBar)
                    .onChange(of: editedSettings.showMenuBar) { isDirty = true }
            }

            Section("Excluded Repos") {
                if viewModel.excludedRepos.isEmpty {
                    Text("No excluded repos")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.excludedRepos) { repo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(repo.name).font(.body)
                                Text(repo.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") {
                                viewModel.include(repo)
                            }
                        }
                    }
                }
            }

            if isDirty {
                Section {
                    Button("Apply Changes") {
                        viewModel.updateSettings(editedSettings)
                        isDirty = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            editedSettings = viewModel.settings
        }
    }
}
