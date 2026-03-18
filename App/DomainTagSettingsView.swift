import SwiftUI

struct DomainTagSettingsView: View {
    @Binding var tagStore: DomainTagStore
    let repos: [RepoInfo]
    let onRerunAutoTag: () -> Void

    @State private var newTagText: String = ""
    @State private var isAddingTag: Bool = false
    @State private var popoverRepoPath: String? = nil

    private var availableTags: [DomainTag] {
        DomainTag.presets + tagStore.customTags
    }

    private var sortedRepos: [RepoInfo] {
        repos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            // MARK: Section 1 — Custom Tags
            Section("Custom Tags") {
                let customTags = tagStore.customTags.compactMap { tag -> String? in
                    if case .custom(let name) = tag { return name }
                    return nil
                }

                if customTags.isEmpty && !isAddingTag {
                    Text("No custom tags yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customTags, id: \.self) { tagName in
                        HStack {
                            Text(tagName)
                            Spacer()
                            Button(role: .destructive) {
                                deleteCustomTag(named: tagName)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if isAddingTag {
                    HStack {
                        TextField("New tag name...", text: $newTagText)
                            .textFieldStyle(.plain)
                        Button {
                            confirmAddCustomTag()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderless)
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        isAddingTag = true
                        newTagText = ""
                    } label: {
                        Label("Add custom tag", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            // MARK: Section 2 — Repository Tags
            Section("Repository Tags") {
                ForEach(sortedRepos) { repo in
                    let entry = tagStore.entries[repo.path]
                    let tags = entry?.tags ?? []
                    let isOverride = entry?.isManualOverride == true

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(repo.name)
                                .font(.body)
                            if isOverride {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                popoverRepoPath = repo.path
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                            .popover(isPresented: Binding(
                                get: { popoverRepoPath == repo.path },
                                set: { if !$0 { popoverRepoPath = nil } }
                            )) {
                                tagPickerPopover(for: repo, currentTags: tags)
                            }
                        }

                        if tags.isEmpty {
                            Text("No tags")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags) { tag in
                                        tagChip(tag: tag, repoPath: repo.path)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // MARK: Re-run button
            Section {
                Button("Re-run Auto-tagging") {
                    onRerunAutoTag()
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Domain Tags")
    }

    // MARK: - Subviews

    @ViewBuilder
    private func tagChip(tag: DomainTag, repoPath: String) -> some View {
        Button {
            removeTag(tag, from: repoPath)
        } label: {
            Text(tag.displayName)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tagPickerPopover(for repo: RepoInfo, currentTags: [DomainTag]) -> some View {
        let currentTagIDs = Set(currentTags.map(\.id))
        let addableTags = availableTags.filter { !currentTagIDs.contains($0.id) }

        VStack(alignment: .leading, spacing: 0) {
            if addableTags.isEmpty {
                Text("All tags already assigned")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding()
            } else {
                ForEach(addableTags) { tag in
                    Button {
                        addTag(tag, to: repo.path)
                        popoverRepoPath = nil
                    } label: {
                        Text(tag.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    Divider()
                }
            }
        }
        .frame(minWidth: 180)
    }

    // MARK: - Actions

    private func confirmAddCustomTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let allTagNames = availableTags.map(\.displayName)
        guard !allTagNames.contains(trimmed) else {
            isAddingTag = false
            newTagText = ""
            return
        }
        tagStore.customTags.append(.custom(trimmed))
        isAddingTag = false
        newTagText = ""
    }

    private func deleteCustomTag(named tagName: String) {
        tagStore.customTags.removeAll { tag in
            if case .custom(let name) = tag { return name == tagName }
            return false
        }
        for path in tagStore.entries.keys {
            tagStore.entries[path]?.tags.removeAll { tag in
                if case .custom(let name) = tag { return name == tagName }
                return false
            }
        }
    }

    private func removeTag(_ tag: DomainTag, from repoPath: String) {
        tagStore.entries[repoPath]?.tags.removeAll { $0.id == tag.id }
        tagStore.entries[repoPath]?.isManualOverride = true
    }

    private func addTag(_ tag: DomainTag, to repoPath: String) {
        if tagStore.entries[repoPath] != nil {
            if !tagStore.entries[repoPath]!.tags.contains(where: { $0.id == tag.id }) {
                tagStore.entries[repoPath]!.tags.append(tag)
            }
            tagStore.entries[repoPath]!.isManualOverride = true
        } else {
            tagStore.entries[repoPath] = RepoTagEntry(
                repoPath: repoPath,
                tags: [tag],
                isManualOverride: true
            )
        }
    }
}
