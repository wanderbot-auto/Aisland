import Foundation
import Testing
@testable import AislandApp

@MainActor
struct WhiteNoiseTests {
    @Test
    func catalogContainsAllImportedMoodistSounds() {
        #expect(WhiteNoiseCatalog.allSounds.count == 84)
        #expect(Set(WhiteNoiseCatalog.categories.map(\.id)) == [
            "nature", "rain", "animals", "urban", "places", "transport", "things", "noise",
        ])
        #expect(Set(WhiteNoiseCatalog.allSounds.map(\.id)).count == WhiteNoiseCatalog.allSounds.count)

        for sound in WhiteNoiseCatalog.allSounds {
            #expect(sound.resourceURL != nil, "Missing bundled resource for \(sound.id): \(sound.resourcePath)")
        }
    }

    @Test
    func whiteNoiseStateSelectsMixesVolumesPausesAndClears() {
        let (model, service, _) = makeModel()
        let river = WhiteNoiseCatalog.sound(id: "river")!
        let thunder = WhiteNoiseCatalog.sound(id: "thunder")!

        #expect(!model.whiteNoiseState.hasSelection)
        #expect(model.whiteNoiseState.isPaused)

        model.toggleWhiteNoiseSound(river)
        model.toggleWhiteNoiseSound(thunder)
        model.setWhiteNoiseVolume(0.3, for: river)
        model.setWhiteNoiseGlobalVolume(0.5)

        #expect(model.whiteNoiseState.selectedSoundIDs == ["river", "thunder"])
        #expect(model.whiteNoiseState.volume(for: "river") == 0.3)
        #expect(model.whiteNoiseState.globalVolume == 0.5)
        #expect(!model.whiteNoiseState.isPaused)
        #expect(model.isWhiteNoisePlaying)
        #expect(service.appliedStates.last?.selectedSoundIDs == ["river", "thunder"])

        model.toggleWhiteNoisePaused()
        #expect(model.whiteNoiseState.isPaused)
        #expect(!model.isWhiteNoisePlaying)

        model.toggleWhiteNoisePaused()
        #expect(!model.whiteNoiseState.isPaused)

        model.clearWhiteNoiseMix()
        #expect(model.whiteNoiseState.selectedSoundIDs.isEmpty)
        #expect(model.whiteNoiseState.isPaused)
        #expect(service.stopAllCallCount == 1)
    }

    @Test
    func whiteNoisePersistenceRestoresSelectionAndVolumesWithoutAutoplay() {
        let suiteName = "aisland-white-noise-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let firstService = FakeWhiteNoisePlayerService()
        let first = AppModel(
            temporaryChatConfigurationStore: TemporaryChatConfigurationStore(databaseURL: temporaryDatabaseURL()),
            temporaryChatAPIKeyLoader: { _ in "" },
            temporaryChatAPIKeySaver: { _, _ in },
            whiteNoiseDefaults: defaults,
            whiteNoisePlayerService: firstService
        )
        let cafe = WhiteNoiseCatalog.sound(id: "cafe")!
        let whiteNoise = WhiteNoiseCatalog.sound(id: "white-noise")!

        first.toggleWhiteNoiseSound(cafe)
        first.toggleWhiteNoiseSound(whiteNoise)
        first.setWhiteNoiseVolume(0.25, for: cafe)
        first.setWhiteNoiseVolume(0.9, for: whiteNoise)
        first.setWhiteNoiseGlobalVolume(0.4)

        let second = AppModel(
            temporaryChatConfigurationStore: TemporaryChatConfigurationStore(databaseURL: temporaryDatabaseURL()),
            temporaryChatAPIKeyLoader: { _ in "" },
            temporaryChatAPIKeySaver: { _, _ in },
            whiteNoiseDefaults: defaults,
            whiteNoisePlayerService: FakeWhiteNoisePlayerService()
        )

        #expect(second.whiteNoiseState.selectedSoundIDs == ["cafe", "white-noise"])
        #expect(second.whiteNoiseState.volume(for: "cafe") == 0.25)
        #expect(second.whiteNoiseState.volume(for: "white-noise") == 0.9)
        #expect(second.whiteNoiseState.globalVolume == 0.4)
        #expect(second.whiteNoiseState.isPaused)
        #expect(!second.isWhiteNoisePlaying)
    }

    private func makeModel() -> (AppModel, FakeWhiteNoisePlayerService, UserDefaults) {
        let suiteName = "aisland-white-noise-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let service = FakeWhiteNoisePlayerService()
        let model = AppModel(
            temporaryChatConfigurationStore: TemporaryChatConfigurationStore(databaseURL: temporaryDatabaseURL()),
            temporaryChatAPIKeyLoader: { _ in "" },
            temporaryChatAPIKeySaver: { _, _ in },
            whiteNoiseDefaults: defaults,
            whiteNoisePlayerService: service
        )
        return (model, service, defaults)
    }
}

@MainActor
private final class FakeWhiteNoisePlayerService: WhiteNoisePlayerServicing {
    private(set) var appliedStates: [WhiteNoiseSelectionState] = []
    private(set) var stopAllCallCount = 0

    func apply(state: WhiteNoiseSelectionState, soundsByID: [String: WhiteNoiseSound]) {
        appliedStates.append(state)
    }

    func stopAll() {
        stopAllCallCount += 1
    }
}

private func temporaryDatabaseURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aisland-white-noise-\(UUID().uuidString)")
        .appendingPathComponent("app.sqlite")
}
