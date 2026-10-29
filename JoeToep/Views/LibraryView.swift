import SwiftUI

/// V15: bookmarks, history and recently closed tabs.
struct LibraryView: View {
    @ObservedObject var library: BrowserLibrary
    @ObservedObject var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.joeToepTheme) private var theme
    @State private var section = Section.bookmarks
    @State private var query = ""
    @State private var confirmClear = false
    enum Section: String, CaseIterable, Identifiable {
        case bookmarks = "Bookmarks", history = "History", closed = "Recently closed"
        var id: String { rawValue }
    }

    private func matches(_ item: LibraryItem) -> Bool {
        query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.url.absoluteString.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
                switch section {
                case .bookmarks:
                    let items = library.bookmarks.filter(matches)
                    if items.isEmpty { empty("No bookmarks yet", "Use ⋯ › Add Bookmark (⌘D) on any page.") }
                    ForEach(items) { item in row(item) { library.removeBookmark(item) } }
                case .history:
                    let items = library.history.filter(matches)
                    if items.isEmpty { empty("No history", "Pages you visit appear here (not in private tabs).") }
                    ForEach(groupedHistory(items), id: \.0) { day, entries in
                        SwiftUI.Section(day) {
                            ForEach(entries) { item in row(item) { library.removeHistory(item) } }
                        }
                    }
                case .closed:
                    if workspace.closedTabs.isEmpty { empty("No recently closed tabs", "Closed tabs can be reopened with ⌘⇧T.") }
                    ForEach(Array(workspace.closedTabs.enumerated()), id: \.element.id) { index, saved in
                        Button {
                            if index == 0 { workspace.reopenClosedTab() }
                            else if let url = saved.url { workspace.addTab(url: url) }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(saved.title ?? TabTitleSummarizer.fallbackTitle(for: saved.url)).lineLimit(1)
                                Text(saved.url?.absoluteString ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search \(section.rawValue.lowercased())")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if section == .history && !library.history.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear…", role: .destructive) { confirmClear = true }
                    }
                }
            }
            .confirmationDialog("Clear browsing history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Last hour", role: .destructive) { library.clearHistory(since: Date().addingTimeInterval(-3600)) }
                Button("Today", role: .destructive) { library.clearHistory(since: Calendar.current.startOfDay(for: Date())) }
                Button("All history", role: .destructive) { library.clearHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func groupedHistory(_ items: [LibraryItem]) -> [(String, [LibraryItem])] {
        let formatter = DateFormatter(); formatter.dateStyle = .full; formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        var result: [(String, [LibraryItem])] = []
        for item in items.prefix(600) {
            let day = formatter.string(from: item.date)
            if result.last?.0 == day { result[result.count - 1].1.append(item) } else { result.append((day, [item])) }
        }
        return result
    }

    private func row(_ item: LibraryItem, delete: @escaping () -> Void) -> some View {
        Button {
            workspace.selected.session.load(item.url); dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: NavigationPolicy.isPlaybackPage(item.url) ? "play.rectangle" : "globe")
                    .foregroundStyle(theme.accent).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).lineLimit(1)
                    Text(item.url.host ?? item.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(item.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { workspace.addTab(url: item.url); dismiss() } label: { Label("Open in New Tab", systemImage: "plus.square") }
            Button { workspace.addTab(url: item.url, activate: false) } label: { Label("Open in Background Tab", systemImage: "square.on.square") }
            Button { Clipboard.copy(item.url) } label: { Label("Copy Link", systemImage: "link") }
            Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
        }
        .swipeActions { Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") } }
    }

    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 12)
    }
}

/// V16: Chrome-style find on page (⌘F) on every platform. Typing searches immediately, Enter
/// jumps to the next match (⇧Enter previous), all matches are highlighted.
struct FindBar: View {
    @ObservedObject var session: WebSession
    @Binding var visible: Bool
    @State private var text = ""
    @State private var state = WebSession.FindState()
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool
    @Environment(\.joeToepTheme) private var theme
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.secondary)
            TextField("Find on page", text: $text)
                .textFieldStyle(.plain).frame(minWidth: 140, maxWidth: 260).focused($focused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never).submitLabel(.next)
                #endif
                .onSubmit { session.findNext { state = $0 }; focused = true }
                .onChange(of: text) { _, value in schedule(value) }
                #if os(macOS)
                .onExitCommand { close() }
                #endif
                .accessibilityIdentifier("find.field")
            Text(text.isEmpty ? "" : (state.count == 0 ? "No results" : "\(state.index)/\(state.count)"))
                .font(.caption.monospacedDigit()).foregroundStyle(state.count == 0 && !text.isEmpty ? .red : theme.secondary)
                .frame(minWidth: 54)
            Button { session.findPrevious { state = $0 } } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).disabled(state.count == 0)
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button { session.findNext { state = $0 } } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain).disabled(state.count == 0)
                .keyboardShortcut("g", modifiers: .command)
            Button { session.findPrevious { state = $0 } } label: { EmptyView() }
                .keyboardShortcut(.return, modifiers: .shift).frame(width: 0).opacity(0)
            Button { close() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(theme.secondary) }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityLabel("Close find")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(.horizontal, 12)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
    private func schedule(_ value: String) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            session.find(value) { state = $0 }
        }
    }
    private func close() { session.clearFindHighlights(); visible = false }
}
