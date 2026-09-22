//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

@MainActor
struct PgAppBuildTypeTests {
    // MARK: - BuildConfiguration
    
    @Test
    func buildConfigurationDebugDescription() {
        #expect(BuildConfiguration.debug.description == "Debug")
    }
    
    @Test
    func buildConfigurationReleaseDescription() {
        #expect(BuildConfiguration.release.description == "Release")
    }
    
    // MARK: - AppScheme
    
    @Test
    func appSchemeDevDescription() {
        #expect(AppScheme.dev.description == "dev")
    }
    
    @Test
    func appSchemeTstDescription() {
        #expect(AppScheme.tst.description == "tst")
    }
    
    @Test
    func appSchemeAccDescription() {
        #expect(AppScheme.acc.description == "acc")
    }
    
    @Test
    func appSchemePrdDescription() {
        #expect(AppScheme.prd.description == "prd")
    }
    
    // MARK: - AppBuildType
    
    @Test
    func appBuildTypeDescription() {
        let buildType = AppBuildType(configuration: .debug, scheme: .dev)
        #expect(buildType.description == "Debug-dev")
    }
    
    @Test
    func appBuildTypeReleasePrdDescription() {
        let buildType = AppBuildType(configuration: .release, scheme: .prd)
        #expect(buildType.description == "Release-prd")
    }
    
    @Test
    func appBuildTypeDebugTstDescription() {
        let buildType = AppBuildType(configuration: .debug, scheme: .tst)
        #expect(buildType.description == "Debug-tst")
    }
    
    @Test
    func appBuildTypeReleaseAccDescription() {
        let buildType = AppBuildType(configuration: .release, scheme: .acc)
        #expect(buildType.description == "Release-acc")
    }
}
