//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import QuickLook
import SwiftUI

/* Base QLPreviewController subclass that suppresses QL's title menu,
 intercepts the share/action button to show a warning sheet before sharing,
 and provides hooks for subclass-specific navigation bar customization.
 
 Like Elements "feature" regarding the info button, adding the warning/blocking to the share button is hacky
 since the share button is an OS native button from Quick Look view (not made to do such things).
 This also means the warning or blocking dialogs may not work for iOS 27 or later.
 */

class PgPreviewController: QLPreviewController {
    /// The file URL to share when the action button is tapped.
    /// Subclasses should override this to provide context-specific URLs.
    /// The default implementation returns `fileURL`.
    open var currentFileURL: URL? {
        fileURL
    }

    /// The MIME type of the current file. Subclasses should override this
    /// to provide the MIME type from the media source for blocklist checking.
    open var currentFileMimeType: String? {
        nil
    }

    /// Settable file URL for simple use cases that don't need a subclass override.
    var fileURL: URL?

    /// Optional title text displayed in the navigation bar.
    /// Set this before presentation for a simple centered label. Subclasses that
    /// override `configureNavigationBar()` to install their own header can ignore this.
    var titleText: String?

    private var barButtonDisplayLink: CADisplayLink?

    private(set) weak var quickLookActionSourceView: UIView?

    /// Reusable empty view set as the nav bar's titleView to prevent QL from showing its own title.
    private let titlePlaceholderView = UIView()

    /// A simple label used when `titleText` is set and the subclass doesn't override `configureNavigationBar()`.
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    // MARK: - View hierarchy discovery

    var navigationBar: UINavigationBar? {
        view.subviews.first?.subviews.first { $0 is UINavigationBar } as? UINavigationBar
    }

    var bottomBarItemsContainer: UIView? {
        if #available(iOS 26, *) {
            view.subviews.first?.subviews.last?.subviews.first
        } else {
            view.subviews.first?.subviews.last { $0 is UIToolbar }
        }
    }

    private var bottomBarToolbar: UIToolbar? {
        guard let bottomBarItemsContainer else { return nil }
        return (bottomBarItemsContainer as? UIToolbar) ?? bottomBarItemsContainer.firstSubview(of: UIToolbar.self)
    }

    // MARK: - Lifecycle

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        navigationBar?.topItem?.titleView = titlePlaceholderView

        configureNavigationBar()
        updateBarButtons()

        if barButtonDisplayLink == nil {
            barButtonDisplayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            barButtonDisplayLink?.add(to: .main, forMode: .common)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Restart the display link after a cancelled interactive dismissal (pan-down).
        if barButtonDisplayLink == nil {
            barButtonDisplayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            barButtonDisplayLink?.add(to: .main, forMode: .common)
        }
        updateBarButtons()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        barButtonDisplayLink?.invalidate()
        barButtonDisplayLink = nil
    }

    // MARK: - Subclass hooks

    /// Called from `viewWillLayoutSubviews` to allow subclasses to install custom header views
    /// in the navigation bar. The default implementation shows a simple label when `titleText` is set.
    open func configureNavigationBar() {
        guard let navBar = navigationBar, let titleText, !titleText.isEmpty else { return }

        if titleLabel.superview !== navBar {
            navBar.addSubview(titleLabel)
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
            ])
        }
        titleLabel.text = titleText
    }

    /// Called from `updateBarButtons` to allow subclasses to install a custom left bar button item
    /// (e.g. a details/info button). The default implementation does nothing.
    open func updateLeftBarButton() { }

    /// Returns the items to share via the activity view controller.
    /// The default implementation returns only the file URL. Subclasses can override
    /// to add additional items (e.g. a caption).
    open func shareItems(for url: URL) -> [Any] {
        [url]
    }

    // MARK: - Bar button management

    @objc private func displayLinkDidFire() {
        updateBarButtons()
    }

    private func updateBarButtons() {
        if let topItem = navigationBar?.topItem {
            updateLeftBarButton()
            removeQuickLookTitleMenu(from: topItem)
        }

        configureQuickLookActionButton()
    }

    private func removeQuickLookTitleMenu(from navigationItem: UINavigationItem) {
        navigationItem.titleMenuProvider = nil
        navigationItem.documentProperties = nil
        navigationItem.titleView = titlePlaceholderView
        navigationItem.titleView?.isUserInteractionEnabled = false
    }

    // MARK: - Action button interception

    /// Finds and intercepts QL's native share/action button by locating the actual
    /// UIControl in the view hierarchy rather than going through UIBarButtonItem's
    /// target/action (which doesn't work when QL uses UIAction-based items on iOS 18).
    ///
    /// - iOS 18: the share button is the leftmost control in a UIToolbar.
    /// - iOS 26: the share button is the rightmost control in a non-toolbar container.
    private func configureQuickLookActionButton() {
        guard let bottomBarItemsContainer else { return }

        let control: UIControl?
        if bottomBarToolbar != nil {
            // iOS 18: share button is on the left side of the toolbar.
            control = leftmostControl(in: bottomBarItemsContainer)
        } else {
            // iOS 26: share button is on the right side.
            control = rightmostControl(in: bottomBarItemsContainer)
        }

        guard let control else { return }
        quickLookActionSourceView = control
        attachAction(to: control)
    }

    private func leftmostControl(in container: UIView) -> UIControl? {
        let controls = container.allSubviews(of: UIControl.self)
        return controls.min { lhs, rhs in
            lhs.convert(lhs.bounds, to: container).minX < rhs.convert(rhs.bounds, to: container).minX
        }
    }

    private func rightmostControl(in container: UIView) -> UIControl? {
        let controls = container.allSubviews(of: UIControl.self)
        return controls.max { lhs, rhs in
            lhs.convert(lhs.bounds, to: container).maxX < rhs.convert(rhs.bounds, to: container).maxX
        }
    }

    private func attachAction(to control: UIControl) {
        guard !control.allTargets.contains(self) else { return }

        control.removeTarget(nil, action: nil, for: .touchUpInside)
        control.addTarget(self, action: #selector(handleQuickLookActionButton), for: .touchUpInside)
        control.isHidden = false
        control.isUserInteractionEnabled = true
        control.accessibilityLabel = L10n.actionShare
        control.accessibilityTraits = control.accessibilityTraits.union(.button)
    }

    // MARK: - Share flow

    @objc private func handleQuickLookActionButton() {
        guard let fileURL = currentFileURL else { return }
        guard presentedViewController == nil else { return }

        // Block sharing of dangerous file types
        let filename = fileURL.lastPathComponent
        if FileTypeBlocklist.isBlocked(mimeType: currentFileMimeType, filename: filename) {
            let fileExtension = FileTypeBlocklist.fileExtension(from: filename) ?? ""
            var hostingController: UIHostingController<BlockedFileTypeSheetView>?
            let rootView = BlockedFileTypeSheetView(preferredColorScheme: .dark,
                                                    filename: filename,
                                                    fileExtension: fileExtension,
                                                    controlsPresentationDetents: false,
                                                    onHeightChange: { [weak self] height in
                                                        guard self != nil, let hostingController else { return }
                                                        hostingController.sheetPresentationController?.detents = [.height(height)]
                                                    })
            let controller = UIHostingController(rootView: rootView)
            hostingController = controller
            controller.view.backgroundColor = .compound.bgCanvasDefault
            controller.overrideUserInterfaceStyle = .dark
            present(controller, animated: true)
            return
        }

        var hostingController: UIHostingController<AttachmentWarningSheetView>?
        let rootView = AttachmentWarningSheetView(preferredColorScheme: .dark,
                                                  onContinue: { [weak self] in
                                                      self?.dismiss(animated: true) {
                                                          self?.presentShareSheet(url: fileURL)
                                                      }
                                                  },
                                                  controlsPresentationDetents: false,
                                                  onHeightChange: { [weak self] height in
                                                      guard self != nil, let hostingController else { return }
                                                      hostingController.sheetPresentationController?.detents = [.height(height)]
                                                  })
        let controller = UIHostingController(rootView: rootView)
        hostingController = controller
        controller.view.backgroundColor = .compound.bgCanvasDefault
        controller.overrideUserInterfaceStyle = .dark
        present(controller, animated: true)
    }

    private func presentShareSheet(url: URL) {
        let items = shareItems(for: url)

        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            if let sourceView = quickLookActionSourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 1, height: 1)
            }
        }

        present(activityViewController, animated: true)
    }
}

// MARK: - UIView Helpers

extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        for view in subviews {
            if let match = view as? T {
                return match
            }
            if let match = view.firstSubview(of: type) {
                return match
            }
        }
        return nil
    }

    func allSubviews<T: UIView>(of type: T.Type) -> [T] {
        var matches: [T] = []
        for view in subviews {
            if let match = view as? T {
                matches.append(match)
            }
            matches.append(contentsOf: view.allSubviews(of: type))
        }
        return matches
    }
}

private extension UISheetPresentationController.Detent {
    static func height(_ height: CGFloat) -> UISheetPresentationController.Detent {
        .custom { _ in
            height
        }
    }
}
