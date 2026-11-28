import SwiftUI
import PhotosUI
import UIKit
import DoYourWorkCore

/// "Who's this for?": the people as small photo tiles, in settings until someone is picked.
struct PersonChooser: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// The tiles' colour: the surface on the page's background, the background inside a card.
    var tileColor = Color.surface
    let onPick: (Player) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Whose profile?").font(.app(.title3)).fontWeight(.black).foregroundStyle(Color.appText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(store.players) { p in
                    Button { fb.tap(); onPick(p) } label: {
                        VStack(spacing: 0) {
                            AvatarView(player: p, size: 64)
                            Text(store.shownName(p)).font(.app(.caption)).fontWeight(.bold).foregroundStyle(Color.appText)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .padding(.bottom, 8).frame(maxWidth: .infinity)
                        .background(tileColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(BandPress())
                    .accessibilityLabel(store.shownName(p))
                    .accessibilityIdentifier("choose-\(p.id)")
                }
            }
            if store.players.isEmpty {
                Text("Nobody's doing chores yet. An admin can add people in settings, under Admin.").font(.app(.callout)).foregroundStyle(Color.done)
            }
        }
        .padding(16)
    }
}

// MARK: - settings

struct SettingsPage: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let person: Player?
    let onChoose: (Player) -> Void
    let onSwitch: () -> Void
    let onAdmin: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let person {
                    ProfileCard(player: person, onSwitch: onSwitch)
                    BordersCard(player: person)
                } else {
                    GroupCard(padding: 0) { PersonChooser(tileColor: Color.appBackground.opacity(ThemeStore.shared.isGlass ? 0.35 : 1), onPick: onChoose) }
                }
                LookCard()
                adminRow
                about
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var adminRow: some View {
        Button { fb.tap(); onAdmin() } label: {
            HStack {
                Text("Admin").font(.app(.headline)).foregroundStyle(Color.appText)
                Spacer()
                let waiting = store.waitingCount
                if waiting > 0 {
                    Text("\(waiting) waiting").font(.app(.footnote)).fontWeight(.bold).foregroundStyle(Palette.heat.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Palette.heat.stops[0], in: Capsule())
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.done)
            }
            .padding(16).frame(minHeight: 56)
            .panel(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(BandPress())
        .accessibilityIdentifier("admin")
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.isLinked {
                Text("Sync: \(store.syncStatus)")
            } else {
                Text("Everything here stays on this device. No accounts, nothing sent anywhere.")
            }
            Text("Version \(AppInfo.version)")
        }
        .font(.app(.caption)).foregroundStyle(Color.done).padding(.horizontal, 4)
    }
}

/// Their photo, how to change it, and their name.
private struct ProfileCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let player: Player
    let onSwitch: () -> Void
    @State private var libraryItem: PhotosPickerItem?
    @State private var takingSelfie = false
    @State private var choosingCharacter = false
    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var problem: String?

    var body: some View {
        GroupCard {
            HStack(alignment: .center, spacing: 14) {
                AvatarView(player: player, size: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Button { fb.tap(); nameDraft = player.displayName ?? ""; renaming = true } label: {
                        Text(store.shownName(player)).font(.app(.title2)).fontWeight(.black).foregroundStyle(Color.appText)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Changes your display name")
                    Text("Tap your name to change it.").font(.app(.caption)).foregroundStyle(Color.done)
                    Button("Switch person") { fb.tap(); onSwitch() }.font(.app(.footnote)).fontWeight(.bold).foregroundStyle(Color.appText)
                        .frame(minHeight: 36)
                }
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                PillButton(label: "Take a selfie", systemImage: "camera") { fb.tap(); takingSelfie = true }
            }
            PhotosPicker(selection: $libraryItem, matching: .images) {
                PillLabel(label: "Choose a photo", systemImage: "photo")
            }
            .accessibilityIdentifier("choose-photo")
            if player.photo != nil {
                PillButton(label: "Remove photo", systemImage: "trash") { fb.tap(); store.setPhoto(player.id, nil) }
            }
            PillButton(label: player.photo == nil ? "Change character" : "Use a character instead", systemImage: "face.smiling") {
                fb.tap(); choosingCharacter = true
            }
            if let problem { Text(problem).font(.app(.footnote)).foregroundStyle(Theme.bad) }
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run { use(data.flatMap(UIImage.init(data:))); libraryItem = nil }
            }
        }
        .fullScreenCover(isPresented: $takingSelfie) {
            SelfieCamera { use($0) }.ignoresSafeArea()
        }
        .sheet(isPresented: $choosingCharacter) {
            CharacterPicker(current: store.characters[player.id], takenBy: charactersTaken) {
                store.setCharacter(player.id, $0.id)
                // Picking a character means showing it: take the photo off.
                if player.photo != nil { store.setPhoto(player.id, nil) }
            }
        }
        .alert("Display name", isPresented: $renaming) {
            TextField("Anything you like", text: $nameDraft).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { store.setDisplayName(player.id, nameDraft) }
            Button("Use my username", role: .destructive) { store.setDisplayName(player.id, "") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown in place of your username, \(player.name). Your chores and points stay exactly as they are. Up to \(DisplayName.maxLength) characters.")
        }
    }

    private func use(_ image: UIImage?) {
        guard let image else { return }
        if let photo = PhotoCache.profilePhoto(from: image) {
            problem = nil; store.setPhoto(player.id, photo); fb.submit()
        } else {
            problem = "That picture couldn't be used. Try another one?"; fb.error()
        }
    }

    private var charactersTaken: [String: String] {
        let characters = store.characters
        var out: [String: String] = [:]
        for other in store.players where other.id != player.id {
            if let c = characters[other.id] { out[c.id] = store.shownName(other) }
        }
        return out
    }
}

/// Every border around their face: the earned ones to wear, the rest with what they need.
private struct BordersCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let player: Player

    var body: some View {
        let xp = store.totalXp(player.id)
        let worn = Borders.shown(player)?.id ?? "none"
        GroupCard {
            Text("Borders").font(.app(.headline)).foregroundStyle(Color.appText)
            Group {
                if let next = Borders.next(xp: xp) {
                    Text("\(Phrase.count(xp, "point")) so far. \(next.pointsToGo) more for \(next.border.name.lowercased()).")
                } else {
                    Text("\(Phrase.count(xp, "point")). Every border unlocked.")
                }
            }
            .font(.app(.footnote)).foregroundStyle(Color.done)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Borders.all) { b in
                    let open = Borders.isUnlocked(b, xp: xp)
                    let on = b.id == worn
                    Button { fb.tap(); store.setBorder(player.id, b.id) } label: {
                        VStack(spacing: 0) {
                            AvatarView(player: player, size: 64, borderOverride: .some(b.layers.isEmpty ? nil : b))
                            Text(open ? b.name : "at \(b.unlockXp)").font(.app(.caption2)).fontWeight(.semibold)
                                .foregroundStyle(open ? Color.appText : Color.done).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .padding(.bottom, 6).frame(maxWidth: .infinity)
                        .background(Color.appBackground.opacity(ThemeStore.shared.isGlass ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay { if on { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.heat.stops[0], lineWidth: 2.5) } }
                        .opacity(open ? 1 : 0.4)
                    }
                    .buttonStyle(BandPress())
                    .disabled(!open)
                    .accessibilityLabel(b.name)
                    .accessibilityValue(on ? "wearing" : open ? "" : "unlocks at \(b.unlockXp) points")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("border-\(b.id)")
                }
            }
        }
    }
}

/// The phone's own look: dark, light or glass, the theme, and sound.
private struct LookCard: View {
    @EnvironmentObject var fb: Feedback
    @ObservedObject private var themes = ThemeStore.shared

    var body: some View {
        GroupCard {
            Text("Look").font(.app(.headline)).foregroundStyle(Color.appText)
            HStack(spacing: 8) {
                ForEach(Appearance.allCases) { a in
                    let on = themes.appearance == a
                    Button { fb.tap(); themes.appearance = a } label: {
                        VStack(spacing: 4) {
                            Image(systemName: a == .dark ? "moon.fill" : a == .light ? "sun.max.fill" : "drop.fill").font(.system(size: 18, weight: .semibold))
                            Text(a.name).font(.app(.footnote)).fontWeight(.bold)
                        }
                        .foregroundStyle(on ? Palette.heat.ink : Color.appText)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(on ? Palette.heat.stops[0] : Color.appBackground.opacity(themes.isGlass ? 0.35 : 1),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(BandPress())
                    .accessibilityLabel("\(a.name) mode")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("appearance-\(a.rawValue)")
                }
            }
            PillButton(label: "Theme: \(ThemeStore.shared.current.name)", systemImage: "paintpalette") { fb.tap(); ThemeStore.shared.picking = true }
            Toggle(isOn: $fb.soundOn) { Text("Sound").font(.app(.callout)).foregroundStyle(Color.appText) }
                .tint(Palette.heat.stops[0])
        }
    }
}

/// A rounded button inside a card.
struct PillButton: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) { PillLabel(label: label, systemImage: systemImage) }.buttonStyle(BandPress())
    }
}

struct PillLabel: View {
    let label: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            if let systemImage { Image(systemName: systemImage).frame(width: 22) }
            Text(label).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .font(.app(.callout)).fontWeight(.semibold).foregroundStyle(Color.appText)
        .padding(.horizontal, 14).frame(minHeight: 46)
        .background(Color.appBackground.opacity(ThemeStore.shared.isGlass ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// The front camera, for a profile selfie.
struct SelfieCamera: UIViewControllerRepresentable {
    let onPhoto: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(.front) { picker.cameraDevice = .front }
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SelfieCamera
        init(_ parent: SelfieCamera) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onPhoto(info[.originalImage] as? UIImage); parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// The app's version and build, e.g. "1.0 (202611141817)".
enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? "?"
        let b = info["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
