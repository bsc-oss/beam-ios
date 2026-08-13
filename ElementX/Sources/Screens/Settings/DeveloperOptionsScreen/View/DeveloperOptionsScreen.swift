//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import SwiftUI

struct DeveloperOptionsScreen: View {
    @Bindable var context: DeveloperOptionsScreenViewModel.Context
    
    @State private var showConfetti = false
    @State private var elementCallURLOverrideString: String
    
    init(context: DeveloperOptionsScreenViewModel.Context) {
        self.context = context
        elementCallURLOverrideString = context.elementCallBaseURLOverride?.absoluteString ?? ""
    }
    
    var body: some View {
        Form {
            if let storeSizes = context.viewState.storeSizes {
                Section("Usage") {
                    ForEach(storeSizes) { storeSize in
                        LabeledContent(storeSize.name, value: storeSize.size)
                    }
                }
            }
            
            Section("Logging") {
                LogLevelConfigurationView(logLevel: $context.logLevel)
                
                DisclosureGroup("SDK trace packs") {
                    ForEach(TraceLogPack.allCases, id: \.self) { pack in
                        Toggle(isOn: $context.traceLogPacks[pack]) {
                            Text(pack.title)
                        }
                    }
                }
            }
            
            Section("General") {
                Toggle(isOn: $context.linkNewDeviceEnabled) {
                    Text("Link new device with QR code")
                }
                // PG_CHANGED
                Toggle(isOn: $context.shareProfileEnabled) {
                    Text("Share profile")
                }
                // PG_CHANGED
                Toggle(isOn: $context.inviteFriendsEnabled) {
                    Text("Invite friends")
                }
                // PG_CHANGED
                Toggle(isOn: $context.publicRoomCreationEnabled) {
                    Text("Public room creation")
                }
                // PG_CHANGED
                Toggle(isOn: $context.roomDirectorySearchEnabled) {
                    Text("Room directory search")
                }
                
                context.viewState.appHooks
                    .developerOptionsScreenHook
                    .generalSectionRows()
            }
            
            // PG_CHANGED - puts space/community feature behind a feature flag (disabled by default)
            Section("Spaces") {
                Toggle(isOn: $context.spacesEnabled) {
                    Text("Spaces enabled")
                    Text("Toggling will restart the app.")
                }
                .onChange(of: context.spacesEnabled) { _, _ in
                    context.send(viewAction: .clearCache)
                }
            }

            Section("Room List") {
                // PG_CHANGED - upstream replaced the "Hide grey dots" (hideUnreadMessagesBadge) toggle with this picker
                Picker("Room list activity visibility", selection: $context.roomListActivityVisibility) {
                    ForEach(RoomListActivityVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.rawValue.capitalized)
                            .tag(visibility)
                    }
                }
                
                Toggle(isOn: $context.fuzzyRoomListSearchEnabled) {
                    Text("Fuzzy searching")
                }
                
                Toggle(isOn: $context.lowPriorityFilterEnabled) {
                    Text("Low priority filter")
                }
                
                Toggle(isOn: $context.automaticBackPaginationEnabled) {
                    Text("Automatic back pagination")
                    Text("Requires app reboot")
                }
                // PG_CHANGED
                Toggle(isOn: $context.shareRoomEnabled) {
                    Text("Share room")
                }
            }
            
            Section("Timeline") {
                // PG_CHANGED - threads moved from labs to developer options
                Toggle(isOn: $context.threadsEnabled) {
                    Text(L10n.screenLabsEnableThreads)
                    Text(L10n.screenLabsEnableThreadsDescription)
                }
                .onChange(of: context.threadsEnabled) { _, _ in
                    context.send(viewAction: .clearCache)
                }
                
                // PG_CHANGED - upstream dev toggle integrated into PG Timeline section
                Toggle(isOn: $context.roomThreadListEnabled) {
                    Text("Room thread list")
                }
                
                Toggle(isOn: $context.linkPreviewsEnabled) {
                    Text("Link previews")
                    Text("Follows the timeline media visibility settings.")
                    Text("Can leak the device IP address when loading link metadata.")
                        .foregroundStyle(.compound.textCriticalPrimary)
                }
                
                // PG_CHANGED - allows viewSource and copyPermalink TimelineItemMenuAction only on dev builds
                Toggle(isOn: $context.viewSourceEnabled) {
                    Text("View source")
                    Text("Show 'View source' action in message menu")
                }
                
                Toggle(isOn: $context.copyPermalinkEnabled) {
                    Text("Copy permalink")
                    Text("Show 'Copy link to message' action in message menu")
                }
                
                // PG_CHANGED - allows report TimelineItemMenuAction only on dev builds
                Toggle(isOn: $context.reportEnabled) {
                    Text("Report content")
                    Text("Show 'Report content' action in message menu")
                }

                // PG_CHANGED - displays argus entrypoint based on argusEnabled developer option.
                // The home tab bar updates live (see UserSessionFlowCoordinator).
                Toggle(isOn: $context.argusEnabled) {
                    Text("Argus enabled")
                    Text("Show the Argus entrypoint in the home tab bar")
                }

                Toggle(isOn: $context.liveLocationSharingEnabled) {
                    Text("Live location sharing")
                }
            }
                        
            Section("Join rules") {
                Toggle(isOn: $context.knockingEnabled) {
                    Text("Knocking")
                    Text("Ask to join rooms")
                }
                // PG_CHANGED
                Toggle(isOn: $context.joinRoomByAddressEnabled) {
                    Text("Join group by address")
                }
            }
            
            Section {
                Toggle(isOn: $context.enableOnlySignedDeviceIsolationMode) {
                    Text("Exclude insecure devices when sending/receiving messages")
                    Text("Requires app reboot")
                }
            } header: {
                Text("Trust and Decoration")
            } footer: {
                Text("This setting controls how end-to-end encryption (E2EE) keys are exchanged. Enabling it will prevent the inclusion of devices that have not been explicitly verified by their owners.")
            }

            Section {
                TextField("Leave empty to use EC locally", text: $elementCallURLOverrideString)
                    .autocorrectionDisabled(true)
                    .autocapitalization(.none)
                    .foregroundColor(URL(string: elementCallURLOverrideString) == nil ? .red : .primary)
                    .submitLabel(.done)
                    .onSubmit {
                        if elementCallURLOverrideString.isEmpty {
                            context.elementCallBaseURLOverride = nil
                        } else if let url = URL(string: elementCallURLOverrideString) {
                            context.elementCallBaseURLOverride = url
                        }
                    }
            } header: {
                Text("Element Call remote URL override")
            }
            
            Section("Notifications") {
                Toggle(isOn: $context.hideQuietNotificationAlerts) {
                    Text("Hide quiet alerts")
                    Text("The badge count will still be updated")
                }
                Toggle(isOn: $context.focusEventOnNotificationTap) {
                    Text("Focus event on notification tap")
                }
            }
            
            Section {
                Button {
                    showConfetti = true
                } label: {
                    Text("🥳")
                        .frame(maxWidth: .infinity)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 } // Fix separator alignment
                }
            }

            Section {
                Button(role: .destructive) {
                    context.send(viewAction: .clearCache)
                } label: {
                    Text("Clear cache")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(effectsView)
        .navigationTitle(L10n.commonDeveloperOptions)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var effectsView: some View {
        if showConfetti {
            EffectsView(effect: .confetti)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .task { await removeConfettiAfterDelay() }
        }
    }

    private func removeConfettiAfterDelay() async {
        try? await Task.sleep(for: .seconds(4))
        showConfetti = false
    }
}

private struct LogLevelConfigurationView: View {
    @Binding var logLevel: LogLevel
    
    var body: some View {
        Picker(selection: $logLevel) {
            ForEach(logLevels, id: \.self) { logLevel in
                Text(logLevel.title)
            }
        } label: {
            Text("Log level")
            Text("Requires app reboot")
        }
    }
    
    /// Allows the picker to work with associated values
    private var logLevels: [LogLevel] {
        [.error, .warn, .info, .debug, .trace]
    }
}

private extension Set<TraceLogPack> {
    /// A custom subscript that allows binding a toggle to add/remove a pack from the array.
    subscript(pack: TraceLogPack) -> Bool {
        get { contains(pack) }
        set {
            if newValue {
                insert(pack)
            } else {
                remove(pack)
            }
        }
    }
}

// MARK: - Previews

struct DeveloperOptionsScreen_Previews: PreviewProvider {
    static let appSettings = AppSettings() // PG_CHANGED - ServiceLocator removed upstream
    static let viewModel = DeveloperOptionsScreenViewModel(developerOptions: appSettings,
                                                           elementCallBaseURL: appSettings.elementCallBaseURL,
                                                           appHooks: AppHooks(),
                                                           clientProxy: ClientProxyMock(.init()))
    static var previews: some View {
        ElementNavigationStack {
            DeveloperOptionsScreen(context: viewModel.context)
        }
    }
}
