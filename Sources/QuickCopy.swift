import AppKit
import SwiftUI

struct CopyItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var value: String
}

final class ItemStore: ObservableObject {
    @Published var items: [CopyItem] { didSet { save() } }
    private let key = "quickCopy.items"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([CopyItem].self, from: data) {
            items = saved
        } else {
            items = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

final class HoverButton: NSStatusBarButton {
    var onHover: (() -> Void)?
    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { onHover?() }
}

struct PanelView: View {
    @ObservedObject var store: ItemStore
    var onManage: () -> Void
    var onCopy: () -> Void
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick Copy").font(.headline)
                    Text("Your details, one click away").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onManage) { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.borderless).help("Manage items")
            }.padding(16)
            Divider()
            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc").font(.title2).foregroundStyle(.secondary)
                    Text("Nothing here yet").font(.subheadline.weight(.medium))
                    Text("Add your links and details to copy them quickly.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Add your first item", action: onManage).padding(.top, 4)
                }.frame(maxWidth: .infinity).padding(.vertical, 24).padding(.horizontal, 20)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.items) { item in
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.value, forType: .string)
                                copiedID = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onCopy() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: copiedID == item.id ? "checkmark" : "doc.on.doc")
                                        .foregroundStyle(copiedID == item.id ? Color.green : Color.accentColor)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.system(.body, weight: .medium))
                                        Text(item.value).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }.contentShape(Rectangle()).padding(.horizontal, 12).padding(.vertical, 8)
                            }.buttonStyle(HoverRowStyle())
                        }
                    }.padding(6)
                }.frame(maxHeight: 330)
            }
            Divider()
            HStack {
                Button("Manage items…", action: onManage).buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless)
            }.font(.caption).foregroundStyle(.secondary).padding(12)
        }.frame(width: 320)
    }
}

struct HoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }
    struct Row: View {
        let configuration: Configuration
        @State private var hovering = false
        var body: some View {
            configuration.label
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(configuration.isPressed ? 0.12 : (hovering ? 0.07 : 0))))
                .onHover { hovering = $0 }
        }
    }
}

struct ManageView: View {
    @ObservedObject var store: ItemStore
    @State private var name = ""
    @State private var value = ""
    @State private var editingID: UUID?
    @State private var selection: UUID?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your copy items").font(.title2.bold())
                Text("Save the details you reach for often. They stay on this Mac.").foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAVED ITEMS").font(.caption.bold()).foregroundStyle(.secondary)
                    List(selection: $selection) {
                        ForEach(store.items) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name).fontWeight(.medium)
                                Text(item.value).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }.tag(item.id)
                        }
                    }.frame(minWidth: 200, maxWidth: 230, minHeight: 220)
                    HStack {
                        Button { clear() } label: { Image(systemName: "plus") }.help("New item")
                        Button {
                            if let selection { store.items.removeAll { $0.id == selection }; clear() }
                        } label: { Image(systemName: "minus") }.disabled(selection == nil).help("Delete selected item")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(editingID == nil ? "ADD AN ITEM" : "EDIT ITEM").font(.caption.bold()).foregroundStyle(.secondary)
                    Text("Label").font(.caption.weight(.medium))
                    TextField("e.g. LinkedIn", text: $name)
                    Text("Text to copy").font(.caption.weight(.medium))
                    TextEditor(text: $value).font(.body).frame(height: 110)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.25)))
                    Text("Paste a link, phone number, email, or any other text.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        if editingID != nil { Button("Cancel") { clear() } }
                        Spacer()
                        Button(editingID == nil ? "Add item" : "Save changes") { save() }
                            .keyboardShortcut(.defaultAction).disabled(!canSave)
                    }
                    Spacer()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(24).frame(width: 650, height: 390)
        .onChange(of: selection) { id in
            guard let id, let item = store.items.first(where: { $0.id == id }) else { return }
            editingID = id; name = item.name; value = item.value
        }
    }
    private func clear() { selection = nil; editingID = nil; name = ""; value = "" }
    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editingID, let index = store.items.firstIndex(where: { $0.id == editingID }) {
            store.items[index].name = cleanName; store.items[index].value = cleanValue
        } else { store.items.append(CopyItem(name: cleanName, value: cleanValue)) }
        clear()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = ItemStore()
    let popover = NSPopover()
    var statusItem: NSStatusItem!
    var manageWindow: NSWindow?
    var tracking: NSTrackingArea?
    var hoverMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Quick Copy")
        button.action = #selector(togglePopover)
        button.target = self
        button.toolTip = "Quick Copy"
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PanelView(store: store, onManage: { [weak self] in self?.showManage() }, onCopy: { [weak self] in self?.popover.performClose(nil) }))
        // A local and global mouse monitor enables hover without replacing the system's status button.
        hoverMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.checkHover(); return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in self?.checkHover() }
        if store.items.isEmpty { showManage() }
    }
    func checkHover() {
        guard let button = statusItem.button, let window = button.window, !popover.isShown, manageWindow?.isKeyWindow != true else { return }
        let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
        if rect.contains(NSEvent.mouseLocation) { showPopover() }
    }
    func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    func showManage() {
        popover.performClose(nil)
        if manageWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 390), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Quick Copy Settings"
            window.contentView = NSHostingView(rootView: ManageView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            manageWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        manageWindow?.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
