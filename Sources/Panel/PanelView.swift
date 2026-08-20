import MyQuickFinderKit
import SwiftUI

struct PanelView: View {
    private static let panelSpace = "panel"

    @FocusState private var isFocused: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var ancestorMenuBottom: CGFloat = 0
    @Environment(\.openSettings) private var openSettings

    let model: PanelModel
    let terminal: any TerminalLauncher
    let bindings: KeyBindingStore
    let settings: SettingsPresenter
    let onDismiss: () -> Void
    let onContentHeightChange: (CGFloat) -> Void

    private var browser: BrowserModel {
        model.browser
    }

    private var interaction: PanelInteraction {
        PanelInteraction(
            model: model,
            bindings: bindings,
            terminal: terminal,
            settings: settings,
            onDismiss: onDismiss,
            setPanelFocus: { focused in isFocused = focused }
        )
    }

    private var actions: PanelActions {
        interaction.actions
    }

    private var actionPath: String {
        guard !model.isOverlayOwningKeyboard else {
            if model.showsAncestors {
                return String(localized: "panel.ancestors.hint")
            }
            return String(localized: "panel.overlay.hint")
        }
        guard model.hasActionTarget else {
            return String(localized: "panel.noTarget")
        }
        return PathDisplay.abbreviatingHome(model.actionTarget, home: browser.home)
    }

    private var trailingLabel: String? {
        if case let .loading(read, total) = browser.state, let total {
            return String(localized: "panel.loading.progress \(read) \(total)")
        }
        if case .empty = browser.state {
            return String(localized: "panel.count \(0)")
        }
        guard case .populated = browser.state else {
            return nil
        }
        return String(localized: "panel.count \(browser.entries.count)")
    }

    var body: some View {
        VStack(spacing: 0) {
            FavoritesBar(
                model: model,
                bindings: bindings.bindings,
                onActivate: model.selectFavorite,
                onOpen: interaction.openFavorite,
                onOpenPicker: { interaction.run(.openPicker) }
            )
            hairline
            header
                .overlay(alignment: .top) { ancestorMenu }
                .zIndex(1)
            hairline
            content
            hairline
            ActionBar(
                path: actionPath,
                actions: actions.bar,
                onOpenSettings: {
                    interaction.presentSettings(using: { openSettings() })
                }
            )
        }
        .frame(width: DesignTokens.Panel.width)
        .coordinateSpace(name: Self.panelSpace)
        .background(PanelBackground())
        .background(heightReporter)
        .onChange(of: model.showsAncestors) { _, shown in
            if !shown {
                ancestorMenuBottom = 0
                report()
            }
        }
        .overlay(alignment: .top) { overlay }
        .clipShape(RoundedRectangle(
            cornerRadius: DesignTokens.Panel.cornerRadius,
            style: .continuous
        ))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in interaction.handle(press) }
        .onChange(of: model.presentationCount, initial: true) { _, _ in
            interaction.restoreFocus()
        }
    }

    private var heightReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.size.height, initial: true) { _, height in
                    contentHeight = height
                    report()
                }
        }
    }

    @ViewBuilder private var overlay: some View {
        if model.showsHelp {
            HelpOverlay(bindings: bindings.bindings) { interaction.run(.hideHelp) }
        }
    }

    @ViewBuilder private var ancestorMenu: some View {
        if model.showsAncestors, !model.showsHelp {
            AncestorMenu(
                ancestors: model.ancestors,
                selectedIndex: model.ancestorIndex,
                onSelect: model.selectAncestor,
                onConfirm: { interaction.run(.confirmAncestor) }
            )
            .padding(.horizontal, DesignTokens.Panel.listInsetHorizontal)
            .offset(y: DesignTokens.Row.breadcrumbHeight)
            .background(ancestorMenuMeasurer)
        }
    }

    private var ancestorMenuMeasurer: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(
                    of: proxy.frame(in: .named(Self.panelSpace)).maxY,
                    initial: true
                ) { _, bottom in
                    ancestorMenuBottom = bottom + DesignTokens.Panel.listInsetBottom
                    report()
                }
        }
    }

    @ViewBuilder private var header: some View {
        if model.isPicking {
            PathPickerBar(
                model: model.picker,
                onChord: interaction.handleFieldChord,
                exitCap: PanelCommandCopy.shortCap(.dismissPanel, in: bindings.bindings),
                onExit: { interaction.run(.exitPicker) }
            )
        } else {
            BreadcrumbBar(
                breadcrumb: browser.breadcrumb,
                trailingLabel: trailingLabel,
                showsParentHint: Breadcrumb.parentDirectory(of: browser.directory) != nil,
                parentCap: PanelCommandCopy.shortCap(.goToParent, in: bindings.bindings),
                isDenied: browser.isDenied,
                onJump: interaction.jump,
                onExpandAncestors: { interaction.run(.openAncestors) },
                onGoUp: { interaction.run(.goToParent) }
            )
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(DesignTokens.Separator.color)
            .frame(height: DesignTokens.Separator.width)
    }

    @ViewBuilder private var content: some View {
        if model.isPicking {
            PickerList(
                model: model,
                onOpen: { interaction.run(.openInFinder) },
                onToggleFavorite: interaction.toggleFavorite(for:)
            )
        } else {
            browseContent
        }
    }

    @ViewBuilder private var browseContent: some View {
        switch browser.state {
        case .loading:
            LoadingDirectoryView(showsSkeleton: browser.showsSkeleton)
        case .denied:
            DeniedDirectoryView(
                directory: browser.directory,
                isSystemProtected: browser.deniedBySystemProtection,
                needsRelaunch: model.needsRelaunchToApplyAuthorization,
                onAuthorize: model.markAuthorizationRequested,
                finderAction: actions.finder
            )
        case .missing:
            MissingDirectoryView(directory: browser.directory, home: browser.home)
        case .empty:
            EmptyDirectoryView()
        case .populated:
            BrowseList(
                model: model,
                bindings: bindings.bindings,
                onSelect: interaction.selectRow,
                onToggleFavorite: interaction.toggleFavorite(at:),
                onOpen: { interaction.run(.openInFinder) },
                onToggleHidden: { interaction.run(.toggleHidden) }
            )
        case let .failed(message):
            Text(message)
                .font(DesignTokens.Typography.breadcrumbAncestor)
                .foregroundStyle(DesignTokens.Ink.secondary)
                .padding(DesignTokens.Settings.inset)
                .frame(maxWidth: .infinity)
        }
    }

    private func report() {
        onContentHeightChange(max(contentHeight, ancestorMenuBottom))
    }
}

private struct PanelBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = DesignTokens.Surface.material
        view.blendingMode = DesignTokens.Surface.blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
