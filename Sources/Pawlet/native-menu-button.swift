import AppKit
import SwiftUI

enum MenuEntry {
    case action(String, selected: Bool = false, perform: () -> Void)
    case separator
}

struct NativeMenuButton<Label: View>: View {
    let title: String
    let entries: [MenuEntry]
    @ViewBuilder let label: () -> Label
    @State private var presenter = MenuPresenter()

    var body: some View {
        Button { presenter.present(entries) } label: { label() }
            .background(MenuAnchor(presenter: presenter).allowsHitTesting(false))
            .accessibilityLabel(title).accessibilityHint("Opens a menu")
    }
}

struct MenuChoice<Value: Hashable> {
    let value: Value
    let title: String
}

struct ChoiceMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [MenuChoice<Value>]

    private var selectedTitle: String { choices.first { $0.value == selection }?.title ?? title }

    var body: some View {
        NativeMenuButton(title: title, entries: choices.map { choice in
            .action(choice.title, selected: choice.value == selection) { selection = choice.value }
        }) {
            HStack(spacing: 8) {
                Text(selectedTitle)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).accessibilityHidden(true)
            }
        }.buttonStyle(PawletActionStyle()).accessibilityValue(selectedTitle).fixedSize()
    }
}

private final class MenuPresenter {
    weak var anchor: NSView?

    func present(_ entries: [MenuEntry]) {
        guard let anchor = anchor, anchor.window != nil else { return }
        let menu = NSMenu()
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case let .action(title, selected, perform):
                let target = MenuAction(perform: perform)
                let item = NSMenuItem(title: title, action: #selector(MenuAction.invoke), keyEquivalent: "")
                item.target = target
                item.representedObject = target
                item.state = selected ? .on : .off
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height + 4), in: anchor)
    }
}

private final class MenuAction: NSObject {
    let perform: () -> Void
    init(perform: @escaping () -> Void) { self.perform = perform }
    @objc func invoke() { perform() }
}

private struct MenuAnchor: NSViewRepresentable {
    let presenter: MenuPresenter
    func makeNSView(context: Context) -> NSView {
        let view = FlippedMenuAnchor()
        presenter.anchor = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { presenter.anchor = view }
}

private final class FlippedMenuAnchor: NSView {
    override var isFlipped: Bool { true }
}
