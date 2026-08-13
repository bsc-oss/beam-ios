//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

/// Class responsible for displaying an arbitrary number of coordinators within the tab bar.
@Observable class NavigationTabCoordinator<Tag: Hashable>: CoordinatorProtocol, CustomStringConvertible {
    struct Tab {
        let coordinator: CoordinatorProtocol
        let details: TabDetails
        var dismissalCallback: (() -> Void)?
    }
    
    @MainActor
    @Observable class TabDetails {
        /// A unique tab that identifies the tab for selection.
        let tag: Tag
        let title: String
        let icon: KeyPath<CompoundIcons, Image>
        let selectedIcon: KeyPath<CompoundIcons, Image>
        var badgeCount = 0
        // PG_CHANGED - allows hiding the tab bar externally (e.g. when spaces are disabled)
        var barVisibilityOverride: Visibility?
        // PG_CHANGED - when set, the tab acts as a launcher: selecting it runs this closure
        // instead of switching the displayed tab (e.g. to present a full-screen flow).
        var onSelect: (() -> Void)?
        
        /// Provide the tab's split coordinator in here to have the tab bar automatically hidden
        /// when pushing a child into the split view's details on iPhone/compact iPad.
        weak var navigationSplitCoordinator: NavigationSplitCoordinator?
        
        init(tag: Tag, title: String, icon: KeyPath<CompoundIcons, Image>, selectedIcon: KeyPath<CompoundIcons, Image>) {
            self.tag = tag
            self.title = title
            self.icon = icon
            self.selectedIcon = selectedIcon
        }

        // PG_CHANGED - allows hiding the tab bar externally (e.g. when spaces are disabled)
        func barVisibility(in horizontalSizeClass: UserInterfaceSizeClass?) -> Visibility {
            if let barVisibilityOverride {
                barVisibilityOverride
            } else if horizontalSizeClass == .compact, navigationSplitCoordinator?.detailCoordinator != nil {
                // Whilst we support pushing screens on the stack in the sidebarCoordinator, in practice
                // we never do that, so simply checking that the detailCoordinator exists is enough.
                .hidden
            } else {
                .automatic
            }
        }
    }
    
    // MARK: Tabs
    
    fileprivate struct TabModule: Identifiable {
        let module: NavigationModule
        let details: TabDetails
        
        var id: ObjectIdentifier {
            module.id
        }

        @MainActor var coordinator: CoordinatorProtocol? {
            module.coordinator
        }
    }
    
    fileprivate var tabModules = [TabModule]() {
        didSet {
            let diffs = tabModules.map(\.module).difference(from: oldValue.map(\.module))
            diffs.forEach { change in
                switch change {
                case .insert(_, let module, _):
                    logPresentationChange("Set tab", module)
                    module.coordinator?.start()
                case .remove(_, let module, _):
                    logPresentationChange("Remove tab", module)
                    module.tearDown()
                }
            }
        }
    }
    
    /// The current set of coordinators displayed by the tabs.
    var tabCoordinators: [any CoordinatorProtocol] {
        tabModules.compactMap(\.module.coordinator)
    }
    
    // PG_CHANGED: The tags identifying each currently displayed tab.
    var tabTags: [Tag] {
        tabModules.map(\.details.tag)
    }
    
    // PG_CHANGED - adds for unit testing purposes, to be able to verify the correct tabs are being displayed.
    /// Returns the ``TabDetails`` for the given tag, if such a tab exists.
    func tabDetails(for tag: Tag) -> TabDetails? {
        tabModules.first { $0.details.tag == tag }?.details
    }
    
    /// Updates the displayed tabs with the provided array.
    func setTabs(_ tabs: [Tab], animated: Bool = true) {
        var transaction = Transaction()
        transaction.disablesAnimations = !animated

        // PG_CHANGED - non-destructive update: reuse the existing module for a tab whose coordinator
        // instance is unchanged so that re-running setTabs (e.g. to add/remove a tab reactively) only
        // starts/tears down the tabs that actually changed. Rebuilding every module would reset the
        // other tabs' navigation state and snap the selection back to the first tab.
        let previousModules = tabModules
        withTransaction(transaction) {
            tabModules = tabs.map { tab in
                if let existing = previousModules.first(where: { $0.coordinator === tab.coordinator }) {
                    return TabModule(module: existing.module, details: tab.details)
                }
                return TabModule(module: .init(tab.coordinator, dismissalCallback: tab.dismissalCallback), details: tab.details)
            }
        }

        // PG_CHANGED - keep the current selection when its tab is still present; only fall back otherwise.
        if selectedTab == nil || !tabModules.contains(where: { $0.details.tag == selectedTab }) {
            selectedTab = tabModules.first?.details.tag
        }
    }
    
    /// The currently selected tab's tag.
    var selectedTab: Tag?

    // PG_CHANGED - backs the tab view's selection binding: selecting a launcher tab (one whose `TabDetails`
    // carries an `onSelect`) runs that action instead of switching the displayed tab, leaving `selectedTab`
    // untouched.
    func selectTab(_ tag: Tag?) {
        if let tag, let onSelect = tabDetails(for: tag)?.onSelect {
            onSelect() // Launcher tab: run its action without switching the displayed tab.
        } else {
            selectedTab = tag
        }
    }
    
    // MARK: Sheets
    
    fileprivate var sheetModule: NavigationModule? {
        didSet {
            if let oldValue {
                logPresentationChange("Remove sheet", oldValue)
                oldValue.tearDown()
            }
            
            if let sheetModule {
                logPresentationChange("Set sheet", sheetModule)
                sheetModule.coordinator?.start()
            }
        }
    }
    
    var presentationDetents: Set<PresentationDetent> = []
    
    /// The currently presented sheet coordinator.
    var sheetCoordinator: (any CoordinatorProtocol)? {
        sheetModule?.coordinator
    }
    
    /// Present a sheet on top of the stack. If this NavigationStackCoordinator is embedded within a NavigationSplitCoordinator
    /// then the presentation will be proxied to the split
    /// - Parameters:
    ///   - coordinator: the coordinator to display
    ///   - animated: whether to animate the transition or not. Default is true
    ///   - dismissalCallback: called when the sheet has been dismissed, programatically or otherwise
    func setSheetCoordinator(_ coordinator: (any CoordinatorProtocol)?, animated: Bool = true, dismissalCallback: (() -> Void)? = nil) {
        guard let coordinator else {
            sheetModule = nil
            return
        }
        
        if sheetModule?.coordinator === coordinator {
            fatalError("Cannot use the same coordinator more than once")
        }

        var transaction = Transaction()
        transaction.disablesAnimations = !animated

        withTransaction(transaction) {
            sheetModule = NavigationModule(coordinator, dismissalCallback: dismissalCallback)
        }
    }
    
    // MARK: Full Screen Cover
    
    fileprivate var fullScreenCoverModule: NavigationModule? {
        didSet {
            if let oldValue {
                logPresentationChange("Remove fullscreen cover", oldValue)
                oldValue.tearDown()
            }
            
            if let fullScreenCoverModule {
                logPresentationChange("Set fullscreen cover", fullScreenCoverModule)
                fullScreenCoverModule.coordinator?.start()
            }
        }
    }
    
    /// The currently presented fullscreen cover coordinator
    /// Fullscreen covers will be presented through the NavigationSplitCoordinator if provided
    var fullScreenCoverCoordinator: (any CoordinatorProtocol)? {
        fullScreenCoverModule?.coordinator
    }
    
    /// Present a fullscreen cover on top of the stack. If this NavigationStackCoordinator is embedded within a NavigationSplitCoordinator
    /// then the presentation will be proxied to the split
    /// - Parameters:
    ///   - coordinator: the coordinator to display
    ///   - animated: whether to animate the transition or not. Default is true
    ///   - dismissalCallback: called when the fullscreen cover has been dismissed, programatically or otherwise
    func setFullScreenCoverCoordinator(_ coordinator: (any CoordinatorProtocol)?, animated: Bool = true, dismissalCallback: (() -> Void)? = nil) {
        guard let coordinator else {
            fullScreenCoverModule = nil
            return
        }
        
        if fullScreenCoverModule?.coordinator === coordinator {
            fatalError("Cannot use the same coordinator more than once")
        }

        var transaction = Transaction()
        transaction.disablesAnimations = !animated

        withTransaction(transaction) {
            fullScreenCoverModule = NavigationModule(coordinator, dismissalCallback: dismissalCallback)
        }
    }
    
    // MARK: - Overlay
    
    fileprivate var overlayModule: NavigationModule? {
        didSet {
            if let oldValue {
                logPresentationChange("Remove overlay", oldValue)
                oldValue.tearDown()
            }
            
            if let overlayModule {
                logPresentationChange("Set overlay", overlayModule)
                overlayModule.coordinator?.start()
            }
        }
    }
    
    /// The currently displayed overlay coordinator
    var overlayCoordinator: (any CoordinatorProtocol)? {
        overlayModule?.coordinator
    }
    
    enum OverlayPresentationMode { case fullScreen, minimized }
    fileprivate var overlayPresentationMode: OverlayPresentationMode = .minimized
    // PG_CHANGED - the transition used to present/dismiss the overlay. Defaults to a cross-fade (the
    // call screen relies on it); launcher flows pass `.move(edge: .bottom)` for a cover-style slide.
    fileprivate var overlayTransition: AnyTransition = .opacity
    // PG_CHANGED - the animation driving the overlay present/dismiss. Defaults to elementDefault (the call
    // screen relies on it); launcher flows can pass a snappier curve for the slide.
    fileprivate var overlayAnimation: Animation = .elementDefault

    /// Present an overlay on top of the tab view
    /// - Parameters:
    ///   - coordinator: the coordinator to display
    ///   - presentationMode: how the coordinator should be presented
    ///   - transition: the transition used to present and dismiss the overlay
    ///   - animation: the animation driving the present/dismiss transition
    ///   - animated: whether the transition should be animated
    ///   - dismissalCallback: called when the overlay has been dismissed, programatically or otherwise
    func setOverlayCoordinator(_ coordinator: (any CoordinatorProtocol)?,
                               presentationMode: OverlayPresentationMode = .fullScreen,
                               transition: AnyTransition = .opacity,
                               animation: Animation = .elementDefault,
                               animated: Bool = true,
                               dismissalCallback: (() -> Void)? = nil) {
        guard let coordinator else {
            overlayModule = nil
            return
        }

        if overlayModule?.coordinator === coordinator {
            fatalError("Cannot use the same coordinator more than once")
        }

        var transaction = Transaction()
        transaction.disablesAnimations = !animated

        withTransaction(transaction) {
            overlayPresentationMode = presentationMode
            overlayTransition = transition
            overlayAnimation = animation
            overlayModule = NavigationModule(coordinator, dismissalCallback: dismissalCallback)
        }
    }
    
    /// Updates the presentation of the overlay coordinator.
    /// - Parameters:
    ///   - mode: The type of presentation to use.
    ///   - animated: whether the transition should be animated
    func setOverlayPresentationMode(_ mode: OverlayPresentationMode, animated: Bool = true) {
        var transaction = Transaction()
        transaction.disablesAnimations = !animated
        
        withTransaction(transaction) {
            overlayPresentationMode = mode
        }
    }

    // MARK: - Launcher Overlay

    // PG_CHANGED - a second, independent overlay slot stacked alongside the call overlay so a full-screen
    // launcher flow (e.g. Argus) can be presented WITHOUT disturbing the call overlay — keeping an ongoing
    // call (and its PiP controller) alive underneath. Layering between the two is dynamic: the call overlay
    // renders above the launcher whenever it's full-screen, and the launcher re-emerges when the call is
    // minimized for PiP or dismissed. Always full-screen, so there's no `.minimized` mode here.
    fileprivate var launcherOverlayModule: NavigationModule? {
        didSet {
            if let oldValue {
                logPresentationChange("Remove launcher overlay", oldValue)
                oldValue.tearDown()
            }

            if let launcherOverlayModule {
                logPresentationChange("Set launcher overlay", launcherOverlayModule)
                launcherOverlayModule.coordinator?.start()
            }
        }
    }

    /// The currently displayed launcher overlay coordinator
    var launcherOverlayCoordinator: (any CoordinatorProtocol)? {
        launcherOverlayModule?.coordinator
    }

    fileprivate var launcherOverlayTransition: AnyTransition = .opacity
    fileprivate var launcherOverlayAnimation: Animation = .elementDefault

    /// Present a launcher overlay on top of the tab view, independently of the call overlay.
    /// - Parameters:
    ///   - coordinator: the coordinator to display
    ///   - transition: the transition used to present and dismiss the overlay
    ///   - animation: the animation driving the present/dismiss transition
    ///   - animated: whether the transition should be animated
    ///   - dismissalCallback: called when the overlay has been dismissed, programatically or otherwise
    func setLauncherOverlayCoordinator(_ coordinator: (any CoordinatorProtocol)?,
                                       transition: AnyTransition = .opacity,
                                       animation: Animation = .elementDefault,
                                       animated: Bool = true,
                                       dismissalCallback: (() -> Void)? = nil) {
        guard let coordinator else {
            launcherOverlayModule = nil
            return
        }

        if launcherOverlayModule?.coordinator === coordinator {
            fatalError("Cannot use the same coordinator more than once")
        }

        var transaction = Transaction()
        transaction.disablesAnimations = !animated

        withTransaction(transaction) {
            launcherOverlayTransition = transition
            launcherOverlayAnimation = animation
            launcherOverlayModule = NavigationModule(coordinator, dismissalCallback: dismissalCallback)
        }
    }
    
    // MARK: - CoordinatorProtocol
    
    /// No idea if this is particuarly needed for the TabView but we do this for the NavigationStackCoordinator and NavigationSplitCoordinator so it
    /// doesn't seem to harm to also do it here.
    func stop() {
        tabModules.forEach { $0.module.tearDown() }
    }
    
    func toPresentable() -> AnyView {
        AnyView(NavigationTabCoordinatorView(navigationTabCoordinator: self))
    }
    
    // MARK: - CustomStringConvertible
    
    var description: String {
        guard !tabModules.isEmpty else { return "NavigationTabCoordinator(Empty)" }
        return "NavigationTabCoordinator(\(tabCoordinators)"
    }
    
    // MARK: - Private
    
    private func logPresentationChange(_ change: String, _ module: NavigationModule) {
        if let coordinator = module.coordinator {
            MXLog.info("\(self) \(change): \(coordinator)")
        }
    }
}

private struct NavigationTabCoordinatorView<Tag: Hashable>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @Bindable var navigationTabCoordinator: NavigationTabCoordinator<Tag>
    
    @State private var standardAppearance = UITabBarAppearance()

    // PG_CHANGED - retained for the view's lifetime; intercepts launcher-tab selection at the UIKit level.
    @State private var launcherDelegate = LauncherTabBarControllerDelegate()

    var body: some View {
        // PG_CHANGED - drive tab selection through `launcherAwareSelection` (defined below) instead of binding
        // `selectedTab` directly, so launcher-tab selection (e.g. Argus) can be vetoed at the SwiftUI level for iOS 27.
        TabView(selection: launcherAwareSelection) {
            ForEach(navigationTabCoordinator.tabModules) { module in
                module.coordinator?.toPresentable()
                    .id(module.id)
                    .tabItem {
                        Label {
                            Text(module.details.title)
                        } icon: {
                            CompoundIcon(module.details.tag == navigationTabCoordinator.selectedTab ? module.details.selectedIcon : module.details.icon)
                        }
                    }
                    .tag(module.details.tag)
                    .badge(module.details.badgeCount)
                    .toolbar(module.details.barVisibility(in: horizontalSizeClass), for: .tabBar)
            }
        }
        .backportTabBarMinimizeBehaviorOnScrollDown()
        .introspect(.tabView, on: .supportedVersions, customize: configureAppearance)
        .sheet(item: $navigationTabCoordinator.sheetModule) { module in
            module.coordinator?.toPresentable()
                .id(module.id)
        }
        .fullScreenCover(item: $navigationTabCoordinator.fullScreenCoverModule) { module in
            module.coordinator?.toPresentable()
                .id(module.id)
        }
        // PG_CHANGED - the base tab content is covered whenever the call overlay is full-screen or a launcher
        // overlay is presented (a minimized-for-PiP call leaves the base interactive underneath).
        .accessibilityHidden(isCallOverlayFullScreen || navigationTabCoordinator.launcherOverlayModule?.coordinator != nil)
        // PG_CHANGED - both overlays share one ZStack so their z-order can be dynamic: the call overlay renders
        // above the launcher (Argus) when it's full-screen, and the launcher re-emerges when the call is
        // minimized for PiP or dismissed — so Argus survives behind an ongoing call.
        .overlay {
            ZStack {
                if let coordinator = navigationTabCoordinator.overlayModule?.coordinator {
                    coordinator.toPresentable()
                        .opacity(navigationTabCoordinator.overlayPresentationMode == .minimized ? 0 : 1)
                        // A view at opacity 0 still hit-tests, so a minimized (PiP) call must not swallow touches.
                        .allowsHitTesting(navigationTabCoordinator.overlayPresentationMode != .minimized)
                        .accessibilityHidden(navigationTabCoordinator.overlayPresentationMode == .minimized)
                        .transition(navigationTabCoordinator.overlayTransition)
                        .zIndex(isCallOverlayFullScreen ? 2 : 0)
                }

                if let coordinator = navigationTabCoordinator.launcherOverlayModule?.coordinator {
                    coordinator.toPresentable()
                        // Hidden from VoiceOver while the call sits on top of it.
                        .accessibilityHidden(isCallOverlayFullScreen)
                        .transition(navigationTabCoordinator.launcherOverlayTransition)
                        .zIndex(1)
                }
            }
            .animation(.elementDefault, value: navigationTabCoordinator.overlayPresentationMode)
            .animation(navigationTabCoordinator.overlayAnimation, value: navigationTabCoordinator.overlayModule)
            .animation(navigationTabCoordinator.launcherOverlayAnimation, value: navigationTabCoordinator.launcherOverlayModule)
        }
    }

    // PG_CHANGED - routes tab selection through `NavigationTabCoordinator.selectTab(_:)` so launcher tabs
    // (e.g. Argus) run their `onSelect` action instead of switching to placeholder content. This complements
    // `LauncherTabBarControllerDelegate`: on iOS <= 26 the UIKit `shouldSelect` delegate rejects the selection
    // before it ever reaches this binding, so the launcher branch is a no-op there. On iOS 27+ SwiftUI's tab
    // bar adopted the `UITab` API and no longer calls `shouldSelect`, so this binding is the only place the
    // launcher selection can be intercepted. Leaving `selectedTab` unchanged keeps the previously selected tab
    // mounted (never detaching its search controller).
    private var launcherAwareSelection: Binding<Tag?> {
        Binding {
            navigationTabCoordinator.selectedTab
        } set: { newValue in
            navigationTabCoordinator.selectTab(newValue)
        }
    }

    // PG_CHANGED - true when the call overlay is presented and shown full-screen (i.e. not minimized for PiP).
    private var isCallOverlayFullScreen: Bool {
        navigationTabCoordinator.overlayModule?.coordinator != nil && navigationTabCoordinator.overlayPresentationMode == .fullScreen
    }
    
    private func configureAppearance(_ tabBarController: UITabBarController) {
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .compound.iconAccentPrimary // iPhone Portrait
        standardAppearance.compactInlineLayoutAppearance.normal.badgeBackgroundColor = .compound.iconAccentPrimary // iPhone Landscape
        standardAppearance.inlineLayoutAppearance.normal.badgeBackgroundColor = .compound.iconAccentPrimary // iPadOS 17 (doesn't work for 18+)
        tabBarController.tabBar.standardAppearance = standardAppearance

        // PG_CHANGED - taking over the tab bar's delegate in `configureLauncherDelegate` (for the Argus
        // launcher tab) stops SwiftUI's `.tabBarMinimizeBehavior(.onScrollDown)` modifier from applying, so
        // the bar no longer minimizes on scroll. Setting the behaviour directly on the UIKit controller here
        // restores it independently of the delegate. Must run before installing our delegate below.
        if #available(iOS 26.0, *) {
            tabBarController.tabBarMinimizeBehavior = .onScrollDown
        }

        configureLauncherDelegate(tabBarController)
    }

    // PG_CHANGED - lets launcher tabs (those with an `onSelect`) run their action without switching the
    // displayed tab, by rejecting the selection at the UIKit level (shouldSelect -> false). Doing it here
    // rather than from a SwiftUI selection binding ensures the previously selected tab is never detached,
    // which would otherwise corrupt its search controller. SwiftUI's own delegate is preserved (forwarded).
    private func configureLauncherDelegate(_ tabBarController: UITabBarController) {
        if tabBarController.delegate !== launcherDelegate {
            launcherDelegate.forwardingDelegate = tabBarController.delegate
            tabBarController.delegate = launcherDelegate
        }

        launcherDelegate.onShouldSelect = { [navigationTabCoordinator] tabBarController, viewController in
            guard let index = tabBarController.viewControllers?.firstIndex(of: viewController),
                  index < navigationTabCoordinator.tabTags.count,
                  let onSelect = navigationTabCoordinator.tabDetails(for: navigationTabCoordinator.tabTags[index])?.onSelect else {
                return true // Normal tab: allow the switch.
            }

            onSelect() // Launcher tab: run its action…
            return false // …and don't switch the displayed tab.
        }
    }
}

// PG_CHANGED - transparent UITabBarControllerDelegate proxy that rejects selection of launcher tabs while
// forwarding every other delegate call to SwiftUI's own tab bar delegate, so the selection binding for
// normal tabs keeps working.
private final class LauncherTabBarControllerDelegate: NSObject, UITabBarControllerDelegate {
    /// Return `false` to reject the selection (and run the launcher's action), `true` to allow it.
    var onShouldSelect: ((UITabBarController, UIViewController) -> Bool)?
    weak var forwardingDelegate: UITabBarControllerDelegate?

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let onShouldSelect, !onShouldSelect(tabBarController, viewController) {
            return false
        }
        return forwardingDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (forwardingDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        forwardingDelegate?.responds(to: aSelector) == true ? forwardingDelegate : super.forwardingTarget(for: aSelector)
    }
}
