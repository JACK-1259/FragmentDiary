import SwiftUI

struct FolderDetailView: View {
    let folderID: UUID

    @Environment(FolderStore.self) private var folderStore
    @Environment(JournalStore.self) private var store
    @Environment(FragmentCollector.self) private var collector
    @Environment(\.dismiss) private var dismiss
    @State private var composeDraft: DraftModel?
    @State private var showMembers = false
    @State private var confirmDelete = false
    @State private var errorText: String?

    private var folder: SharedFolder? { folderStore.folder(folderID) }

    var body: some View {
        Group {
            if let folder {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(folder)
                        if folder.posts.isEmpty {
                            emptyFeed
                        } else {
                            ForEach(dayGroups(folder), id: \.day) { group in
                                Text(DateText.relativeDay(group.day))
                                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                                    .foregroundStyle(Color.inkMuted)
                                    .padding(.top, 4)
                                ForEach(group.posts) { post in
                                    PostCard(post: post, author: folder.member(post.authorID), isMine: post.authorID == LocalIdentity.id) {
                                        deletePost(post)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .readableColumn()
                }
                .safeAreaInset(edge: .bottom) {
                    Button("이 폴더에 쓰기", action: startCompose)
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("멤버와 초대", systemImage: "person.2") { showMembers = true }
                            if folder.ownerID == LocalIdentity.id {
                                Button("폴더 삭제", systemImage: "trash", role: .destructive) { confirmDelete = true }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("폴더 메뉴")
                    }
                }
                .sheet(item: $composeDraft) { draft in
                    FolderComposeSheet(draft: draft, folder: folder) { composeDraft = nil }
                }
                .sheet(isPresented: $showMembers) {
                    MembersSheet(folder: folder)
                }
            } else {
                ContentUnavailableView("폴더를 찾을 수 없어요", systemImage: "folder")
            }
        }
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("이 폴더를 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive, action: deleteFolder)
        } message: {
            Text("폴더에 올린 기록과 사진이 모두 지워져요. 개인 일기는 그대로 남아요.")
        }
        .alert(
            "문제가 생겼어요",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func header(_ folder: SharedFolder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(folder.name)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Button {
                showMembers = true
            } label: {
                HStack(spacing: 10) {
                    MemberStack(members: folder.members)
                    Text("멤버 \(folder.members.count)명")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkMuted)
                    Text("초대하기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .buttonStyle(.plain)
            SyncStatusNote()
        }
    }

    private var emptyFeed: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("첫 기록을 올려보세요")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text("오늘의 조각 중 함께 보고 싶은 것만 골라 올릴 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func dayGroups(_ folder: SharedFolder) -> [(day: Date, posts: [SharedPost])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: folder.posts) { calendar.startOfDay(for: $0.day) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day, default: []].sorted { $0.createdAt > $1.createdAt })
        }
    }

    private func startCompose() {
        // Today's drawing page is offered too, unchecked like everything else.
        let drawing = store.entry(on: .now)?.drawing.map { [$0] } ?? []
        composeDraft = DraftModel(day: .now, existing: nil, collected: collector.collect(on: .now) + drawing, preselectCollected: false)
    }

    private func deletePost(_ post: SharedPost) {
        do {
            try folderStore.deletePost(post.id, in: folderID)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteFolder() {
        do {
            try folderStore.deleteFolder(folderID)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct PostCard: View {
    let post: SharedPost
    let author: Member?
    let isMine: Bool
    let onDelete: () -> Void

    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MemberAvatar(name: author?.name ?? "?", color: author?.color ?? Color.inkMuted, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(author.map { isMine ? "\($0.name) (나)" : $0.name } ?? "알 수 없음")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(DateText.time(post.createdAt))
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                if let mood = post.mood {
                    HStack(spacing: 5) {
                        Circle().fill(mood.color).frame(width: 8, height: 8)
                        Text(mood.label)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.inkMuted)
                }
                if isMine {
                    Menu {
                        Button("삭제", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("기록 메뉴")
                }
            }

            if !post.note.isEmpty {
                Text(post.note)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(post.fragments) { fragment in
                VStack(alignment: .leading, spacing: 8) {
                    switch fragment.kind {
                    case .photos:
                        PhotoCollage(photos: fragment.attachmentIDs.map(PhotoRef.attachment), height: 140)
                    case .event:
                        EventSummary(fragment: fragment.asFragment)
                    case .note:
                        EmptyView()
                    case .drawing:
                        if let id = fragment.attachmentIDs.first {
                            NotebookPage(day: fragment.start, weather: fragment.weather, text: fragment.caption) {
                                AttachmentThumbnail(attachmentID: id)
                            }
                        }
                    }
                    if !fragment.caption.isEmpty && fragment.kind != .drawing {
                        Text(fragment.caption)
                            .font(fragment.kind == .note ? .body : .subheadline)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .confirmationDialog("이 기록을 폴더에서 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive, action: onDelete)
        }
    }
}

private struct FolderComposeSheet: View {
    let draft: DraftModel
    let folder: SharedFolder
    let onClose: () -> Void

    @Environment(FolderStore.self) private var folderStore
    @Environment(JournalStore.self) private var store
    @State private var isPosting = false
    @State private var errorText: String?

    private var audience: String {
        let others = folder.members.filter { $0.id != LocalIdentity.id }.map(\.name)
        return others.isEmpty ? "아직 초대한 사람이 없어요" : "\(others.joined(separator: ", "))님이 볼 수 있어요"
    }

    var body: some View {
        ComposerView(draft: draft, saveTitle: "\(folder.name)에 올리기", onSave: post, onCancel: onClose) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(folder.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("고른 조각만 폴더에 올라가요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(audience)
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(folder.color.opacity(0.14)))
        }
        .disabled(isPosting)
        .overlay {
            if isPosting {
                ProgressView("올리는 중…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .interactiveDismissDisabled()
        .alert(
            "올리지 못했어요",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func post(_ entry: DiaryEntry) {
        isPosting = true
        Task {
            do {
                try await folderStore.post(entry, to: folder.id, author: LocalIdentity.id, journalImage: store.attachmentData)
                onClose()
            } catch {
                errorText = error.localizedDescription
            }
            isPosting = false
        }
    }
}

private struct MembersSheet: View {
    let folder: SharedFolder

    @Environment(FolderStore.self) private var folderStore
    @Environment(\.dismiss) private var dismiss
    @State private var inviteURL: URL?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section("멤버") {
                    ForEach(folder.members) { member in
                        HStack(spacing: 12) {
                            MemberAvatar(member: member, size: 32)
                            Text(member.id == LocalIdentity.id ? "\(member.name) (나)" : member.name)
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text(member.role == .owner ? "만든 사람" : "멤버")
                                .font(.caption)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
                .listRowBackground(Color.card)

                Section {
                    if let inviteURL {
                        ShareLink(item: inviteURL) {
                            Label("초대 링크 보내기", systemImage: "link.badge.plus")
                        }
                    } else if folderStore.sync.isAvailable {
                        Button {
                            Task { await makeInvite() }
                        } label: {
                            Label("초대 링크 만들기", systemImage: "link.badge.plus")
                        }
                    } else {
                        HStack {
                            Label("초대 링크 만들기", systemImage: "link.badge.plus")
                            Spacer()
                            Text("동기화 필요")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.inkMuted)
                    }
                } header: {
                    Text("초대")
                } footer: {
                    Text(folderStore.sync.isAvailable
                         ? "링크를 받은 사람은 이 폴더에만 참여해요. 개인 일기는 공유되지 않아요."
                         : "초대하려면 iCloud 동기화 연결이 필요해요. 연결되면 링크 하나로 가족이나 친구를 이 폴더에 초대할 수 있어요.")
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .alert(
                "초대 링크를 만들지 못했어요",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func makeInvite() async {
        do {
            inviteURL = try await folderStore.sync.inviteLink(for: folder)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
