import SwiftUI

struct CollectionHubView: View {
    @State private var ownership: [AlbumOwnership] = []
    @State private var checklists: [MusicChecklist] = []
    @State private var showingCreateChecklist = false

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    EditorialTitle(eyebrow: "Physical + digital", title: "The record shelf", subtitle: "Track what you own and what you still want to find.")

                    HStack {
                        Text("Owned albums").font(.system(.title2, design: .serif, weight: .bold))
                        Spacer()
                        Text("\(ownership.count) formats").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
                    if ownership.isEmpty {
                        Text("Mark a format from any album page and it will appear here.")
                            .foregroundStyle(.secondary).ymCard()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(ownership) { item in
                                    NavigationLink { AlbumDetailView(albumID: item.albumId) } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ArtworkView(url: item.coverUrl, size: 128, cornerRadius: 18)
                                            Text(item.albumName).font(.headline).lineLimit(1)
                                            Label(item.mediaFormat.label, systemImage: item.mediaFormat.icon)
                                                .font(.caption.weight(.bold)).foregroundStyle(YMColor.cobalt)
                                        }
                                        .frame(width: 128, alignment: .leading)
                                        .foregroundStyle(YMColor.ink)
                                    }
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Checklists").font(.system(.title2, design: .serif, weight: .bold))
                        Spacer()
                        Button { showingCreateChecklist = true } label: { Image(systemName: "plus") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    ForEach(checklists) { checklist in
                        NavigationLink {
                            ChecklistDetailView(checklist: checklist) {
                                checklists.removeAll { $0.id == checklist.id }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(checklist.name).font(.headline)
                                    Spacer()
                                    Text("\(checklist.completedCount)/\(checklist.itemCount)").font(.caption.weight(.bold))
                                }
                                ProgressView(value: checklist.progress).tint(YMColor.orange)
                            }
                            .foregroundStyle(YMColor.ink)
                            .ymCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingCreateChecklist, onDismiss: { Task { await load() } }) { CreateChecklistSheet() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() async {
        async let formats = YourMusicAPI.ownership()
        async let lists = YourMusicAPI.checklists()
        do {
            ownership = try await formats
            checklists = try await lists
        } catch {
            ownership = []
            checklists = []
        }
    }
}

struct ChecklistDetailView: View {
    let checklist: MusicChecklist
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var payload: ChecklistPayload?
    @State private var newItem = ""
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        ZStack {
            YourMusicBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorialTitle(eyebrow: "Checklist", title: checklist.name, subtitle: checklist.description)
                    HStack {
                        TextField("Add something to find or hear", text: $newItem)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            Task {
                                try? await YourMusicAPI.addChecklistItem(checklistID: checklist.id, title: newItem)
                                newItem = ""
                                await load()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ForEach(payload?.items ?? []) { item in
                        Button {
                            Task {
                                try? await YourMusicAPI.setChecklistItem(checklistID: checklist.id, itemID: item.id, complete: !item.isComplete)
                                await load()
                            }
                        } label: {
                            HStack {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.title2).foregroundStyle(item.isComplete ? YMColor.cobalt : YMColor.ink.opacity(0.36))
                                Text(item.title)
                                    .strikethrough(item.isComplete)
                                Spacer()
                            }
                            .foregroundStyle(YMColor.ink)
                            .ymCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete checklist")
                .disabled(isDeleting)
            }
        }
        .confirmationDialog(
            "Delete \"\(checklist.name)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete checklist", role: .destructive) {
                Task { await deleteChecklist() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the checklist and all of its items.")
        }
        .alert(
            "Could not delete checklist",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private func load() async { payload = try? await YourMusicAPI.checklist(checklist.id) }

    private func deleteChecklist() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await YourMusicAPI.deleteChecklist(checklist.id)
            onDeleted()
            dismiss()
        } catch {
            deletionError = error.localizedDescription
        }
    }
}

private struct CreateChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Checklist name", text: $name)
                TextField("Description (optional)", text: $description, axis: .vertical)
            }
            .navigationTitle("New checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            _ = try? await YourMusicAPI.createChecklist(name: name, description: description.isEmpty ? nil : description)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
