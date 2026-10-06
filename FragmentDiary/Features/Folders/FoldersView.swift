import SwiftUI

extension Member {
    var color: Color { Mood.allCases[colorIndex % Mood.allCases.count].color }
}

extension SharedFolder {
    var color: Color { Mood.allCases[colorIndex % Mood.allCases.count].color }
}

struct FoldersView: View {
    @Environment(FolderStore.self) private var folderStore
    @State private var showNewFolder = false

    private var sortedFolders: [SharedFolder] {
        folderStore.folders.sorted { ($0.latestPost?.createdAt ?? $0.createdAt) > ($1.latestPost?.createdAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if folderStore.folders.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SyncStatusNote()
                            .padding(.bottom, 4)
                        ForEach(sortedFolders) { folder in
                            NavigationLink(value: folder.id) {
                                FolderCard(folder: folder)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .readableColumn()
                }
            }
            .background(Color.paper)
            .navigationTitle("함께")
            .navigationDestination(for: UUID.self) { id in
                FolderDetailView(folderID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewFolder = true
                    } label: {
                        Label("새 폴더", systemImage: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showNewFolder) {
                NewFolderSheet { showNewFolder = false }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: -14) {
                MemberAvatar(name: "나", color: Mood.bright.color, size: 56)
                MemberAvatar(name: "+", color: Mood.calm.color, size: 56)
            }
            .padding(.bottom, 4)
            Text("함께 쓰는 폴더")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Text("가족, 연인, 친구를 초대해서 같은 폴더에 하루를 남겨보세요. 폴더에 올린 기록만 함께 보고, 개인 일기는 지금처럼 이 기기에만 남아요.")
                .font(.subheadline)
                .foregroundStyle(Color.inkMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Button("첫 폴더 만들기") { showNewFolder = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            SyncStatusNote()
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }
}

/// Honest about the current state: nothing leaves the device until sync is connected.
struct SyncStatusNote: View {
    @Environment(FolderStore.self) private var folderStore

    var body: some View {
        if !folderStore.sync.isAvailable {
            Label("동기화 연결 전이라 폴더 기록은 지금 이 기기에만 저장돼요", systemImage: "icloud.slash")
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
        }
    }
}

struct MemberAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
            .overlay(Circle().stroke(Color.card, lineWidth: 2))
            .accessibilityLabel(name)
    }
}

extension MemberAvatar {
    init(member: Member, size: CGFloat = 28) {
        self.init(name: member.name, color: member.color, size: size)
    }
}

struct MemberStack: View {
    let members: [Member]
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: -8) {
            ForEach(members.prefix(4)) { member in
                MemberAvatar(member: member, size: size)
            }
            if members.count > 4 {
                MemberAvatar(name: "+\(members.count - 4)", color: Color.inkMuted, size: size)
            }
        }
    }
}

private struct FolderCard: View {
    let folder: SharedFolder

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            FolderCover(color: folder.color)
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.ink)
                MemberStack(members: folder.members, size: 22)
                Text(latestLine)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(14)
        .cardStyle()
    }

    private var latestLine: String {
        guard let post = folder.latestPost else { return "아직 올라온 기록이 없어요" }
        let author = folder.member(post.authorID)?.name ?? "알 수 없음"
        return "\(author) · \(DateText.relativeDay(post.createdAt)) · 기록 \(folder.posts.count)개"
    }
}

/// Stacked sheets in the folder's color — the same card motif as the rest of the app.
private struct FolderCover: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.45))
                .frame(width: 40, height: 50)
                .rotationEffect(.degrees(-8))
                .offset(x: -4)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 40, height: 50)
                .rotationEffect(.degrees(4))
                .overlay {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(4))
                }
        }
        .frame(width: 54, height: 60)
        .accessibilityHidden(true)
    }
}

private struct NewFolderSheet: View {
    let onClose: () -> Void

    @Environment(FolderStore.self) private var folderStore
    @AppStorage(LocalIdentity.nameKey) private var myName = ""
    @State private var name = ""
    @State private var colorIndex = Mood.bright.rawValue
    @State private var errorText: String?

    private var canCreate: Bool { !name.trimmed.isEmpty && !myName.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section("폴더 이름") {
                        TextField("예: 우리 가족, 민지와 나", text: $name)
                    }
                    Section("색") {
                        HStack(spacing: 0) {
                            ForEach(Mood.allCases) { mood in
                                Button {
                                    colorIndex = mood.rawValue
                                } label: {
                                    Circle()
                                        .fill(mood.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().stroke(Color.ink, lineWidth: colorIndex == mood.rawValue ? 2 : 0).padding(-4))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(mood.label)
                                .accessibilityAddTraits(colorIndex == mood.rawValue ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    Section {
                        TextField("이 폴더에서 보일 내 이름", text: $myName)
                    } header: {
                        Text("내 이름")
                    } footer: {
                        Text("초대한 사람에게 이 이름으로 보여요. 설정에서 바꿀 수 있어요.")
                    }
                }
                .listRowBackground(Color.card)
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("새 폴더")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기", action: create)
                        .disabled(!canCreate)
                }
            }
            .alert(
                "폴더를 만들지 못했어요",
                isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func create() {
        myName = myName.trimmed
        let owner = Member(id: LocalIdentity.id, name: myName, role: .owner, colorIndex: colorIndex)
        do {
            try folderStore.createFolder(name: name.trimmed, colorIndex: colorIndex, owner: owner)
            onClose()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
