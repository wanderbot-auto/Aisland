import AVFoundation
import Foundation

@MainActor
protocol WhiteNoisePlayerServicing: AnyObject {
    func apply(state: WhiteNoiseSelectionState, soundsByID: [String: WhiteNoiseSound])
    func stopAll()
}

@MainActor
final class WhiteNoisePlayerService: WhiteNoisePlayerServicing {
    private var players: [String: AVAudioPlayer] = [:]

    func apply(state: WhiteNoiseSelectionState, soundsByID: [String: WhiteNoiseSound]) {
        let selectedIDs = state.selectedSoundIDSet

        for soundID in players.keys where !selectedIDs.contains(soundID) {
            players[soundID]?.stop()
            players[soundID] = nil
        }

        guard state.hasSelection else {
            stopAll()
            return
        }

        for soundID in state.selectedSoundIDs {
            guard let sound = soundsByID[soundID] else { continue }
            let player = player(for: soundID, sound: sound)
            player?.numberOfLoops = -1
            player?.volume = Float(max(0, min(1, state.globalVolume * state.volume(for: soundID))))

            if state.isPaused {
                player?.pause()
            } else if player?.isPlaying != true {
                player?.play()
            }
        }
    }

    func stopAll() {
        for player in players.values {
            player.stop()
        }
        players.removeAll()
    }

    private func player(for soundID: String, sound: WhiteNoiseSound) -> AVAudioPlayer? {
        if let existing = players[soundID] {
            return existing
        }

        guard let url = sound.resourceURL else {
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[soundID] = player
            return player
        } catch {
            return nil
        }
    }
}
