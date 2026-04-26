import Foundation

struct WhiteNoiseSound: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let label: String
    let resourcePath: String
    let systemImageName: String

    var resourceURL: URL? {
        let path = resourcePath as NSString
        let directory = path.deletingLastPathComponent
        let filename = path.lastPathComponent as NSString
        let bundle = Bundle.appResources
        return bundle.url(
            forResource: filename.deletingPathExtension,
            withExtension: filename.pathExtension,
            subdirectory: directory.isEmpty ? nil : directory
        ) ?? bundle.url(
            forResource: filename.deletingPathExtension,
            withExtension: filename.pathExtension
        )
    }
}

struct WhiteNoiseCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImageName: String
    let sounds: [WhiteNoiseSound]
}

struct WhiteNoiseSelectionState: Equatable, Codable, Sendable {
    static let defaultItemVolume: Double = 0.6
    static let defaultGlobalVolume: Double = 0.75

    var selectedSoundIDs: [String]
    var itemVolumes: [String: Double]
    var globalVolume: Double
    var isPaused: Bool

    init(
        selectedSoundIDs: [String] = [],
        itemVolumes: [String: Double] = [:],
        globalVolume: Double = Self.defaultGlobalVolume,
        isPaused: Bool = true
    ) {
        self.selectedSoundIDs = selectedSoundIDs
        self.itemVolumes = itemVolumes
        self.globalVolume = globalVolume
        self.isPaused = isPaused
    }

    var selectedSoundIDSet: Set<String> {
        Set(selectedSoundIDs)
    }

    var hasSelection: Bool {
        !selectedSoundIDs.isEmpty
    }

    var isPlaying: Bool {
        hasSelection && !isPaused
    }

    func contains(_ soundID: String) -> Bool {
        selectedSoundIDSet.contains(soundID)
    }

    func volume(for soundID: String) -> Double {
        itemVolumes[soundID] ?? Self.defaultItemVolume
    }
}

enum WhiteNoiseCatalog {
    static let categories: [WhiteNoiseCategory] = [
        WhiteNoiseCategory(
            id: "nature",
            title: "Nature",
            systemImageName: "tree.fill",
            sounds: [
                sound("river", "River", "nature/river.mp3", "water.waves"),
                sound("waves", "Waves", "nature/waves.mp3", "water.waves"),
                sound("campfire", "Campfire", "nature/campfire.mp3", "flame.fill"),
                sound("wind", "Wind", "nature/wind.mp3", "wind"),
                sound("howling-wind", "Howling Wind", "nature/howling-wind.mp3", "wind"),
                sound("wind-in-trees", "Wind in Trees", "nature/wind-in-trees.mp3", "tree.fill"),
                sound("waterfall", "Waterfall", "nature/waterfall.mp3", "drop.fill"),
                sound("walk-in-snow", "Walk in Snow", "nature/walk-in-snow.mp3", "snowflake"),
                sound("walk-on-leaves", "Walk on Leaves", "nature/walk-on-leaves.mp3", "leaf.fill"),
                sound("walk-on-gravel", "Walk on Gravel", "nature/walk-on-gravel.mp3", "circle.hexagongrid.fill"),
                sound("droplets", "Droplets", "nature/droplets.mp3", "drop.fill"),
                sound("jungle", "Jungle", "nature/jungle.mp3", "tree.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "rain",
            title: "Rain",
            systemImageName: "cloud.rain.fill",
            sounds: [
                sound("light-rain", "Light Rain", "rain/light-rain.mp3", "cloud.drizzle.fill"),
                sound("heavy-rain", "Heavy Rain", "rain/heavy-rain.mp3", "cloud.heavyrain.fill"),
                sound("thunder", "Thunder", "rain/thunder.mp3", "cloud.bolt.rain.fill"),
                sound("rain-on-window", "Rain on Window", "rain/rain-on-window.mp3", "rectangle.split.3x1.fill"),
                sound("rain-on-car-roof", "Rain on Car Roof", "rain/rain-on-car-roof.mp3", "car.fill"),
                sound("rain-on-umbrella", "Rain on Umbrella", "rain/rain-on-umbrella.mp3", "umbrella.fill"),
                sound("rain-on-tent", "Rain on Tent", "rain/rain-on-tent.mp3", "tent.fill"),
                sound("rain-on-leaves", "Rain on Leaves", "rain/rain-on-leaves.mp3", "leaf.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "animals",
            title: "Animals",
            systemImageName: "pawprint.fill",
            sounds: [
                sound("birds", "Birds", "animals/birds.mp3", "bird.fill"),
                sound("seagulls", "Seagulls", "animals/seagulls.mp3", "bird.fill"),
                sound("crickets", "Crickets", "animals/crickets.mp3", "ant.fill"),
                sound("wolf", "Wolf", "animals/wolf.mp3", "pawprint.fill"),
                sound("owl", "Owl", "animals/owl.mp3", "bird.fill"),
                sound("frog", "Frog", "animals/frog.mp3", "lizard.fill"),
                sound("dog-barking", "Dog Barking", "animals/dog-barking.mp3", "dog.fill"),
                sound("horse-gallop", "Horse Gallop", "animals/horse-gallop.mp3", "hare.fill"),
                sound("cat-purring", "Cat Purring", "animals/cat-purring.mp3", "cat.fill"),
                sound("crows", "Crows", "animals/crows.mp3", "bird.fill"),
                sound("whale", "Whale", "animals/whale.mp3", "fish.fill"),
                sound("beehive", "Beehive", "animals/beehive.mp3", "hexagon.fill"),
                sound("woodpecker", "Woodpecker", "animals/woodpecker.mp3", "bird.fill"),
                sound("chickens", "Chickens", "animals/chickens.mp3", "bird.fill"),
                sound("cows", "Cows", "animals/cows.mp3", "pawprint.fill"),
                sound("sheep", "Sheep", "animals/sheep.mp3", "pawprint.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "urban",
            title: "Urban",
            systemImageName: "building.2.fill",
            sounds: [
                sound("highway", "Highway", "urban/highway.mp3", "road.lanes"),
                sound("road", "Road", "urban/road.mp3", "road.lanes"),
                sound("ambulance-siren", "Ambulance Siren", "urban/ambulance-siren.mp3", "siren.fill"),
                sound("busy-street", "Busy Street", "urban/busy-street.mp3", "waveform"),
                sound("crowd", "Crowd", "urban/crowd.mp3", "person.3.fill"),
                sound("traffic", "Traffic", "urban/traffic.mp3", "car.2.fill"),
                sound("fireworks", "Fireworks", "urban/fireworks.mp3", "sparkles"),
            ]
        ),
        WhiteNoiseCategory(
            id: "places",
            title: "Places",
            systemImageName: "mappin.and.ellipse",
            sounds: [
                sound("cafe", "Cafe", "places/cafe.mp3", "cup.and.saucer.fill"),
                sound("airport", "Airport", "places/airport.mp3", "airplane"),
                sound("church", "Church", "places/church.mp3", "building.columns.fill"),
                sound("temple", "Temple", "places/temple.mp3", "building.columns.fill"),
                sound("construction-site", "Construction Site", "places/construction-site.mp3", "hammer.fill"),
                sound("underwater", "Underwater", "places/underwater.mp3", "water.waves"),
                sound("crowded-bar", "Crowded Bar", "places/crowded-bar.mp3", "wineglass.fill"),
                sound("night-village", "Night Village", "places/night-village.mp3", "moon.stars.fill"),
                sound("subway-station", "Subway Station", "places/subway-station.mp3", "tram.fill"),
                sound("office", "Office", "places/office.mp3", "building.2.fill"),
                sound("supermarket", "Supermarket", "places/supermarket.mp3", "basket.fill"),
                sound("carousel", "Carousel", "places/carousel.mp3", "circle.grid.cross.fill"),
                sound("laboratory", "Laboratory", "places/laboratory.mp3", "testtube.2"),
                sound("laundry-room", "Laundry Room", "places/laundry-room.mp3", "washer.fill"),
                sound("restaurant", "Restaurant", "places/restaurant.mp3", "fork.knife"),
                sound("library", "Library", "places/library.mp3", "books.vertical.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "transport",
            title: "Transport",
            systemImageName: "tram.fill",
            sounds: [
                sound("train", "Train", "transport/train.mp3", "train.side.front.car"),
                sound("inside-a-train", "Inside a Train", "transport/inside-a-train.mp3", "train.side.front.car"),
                sound("airplane", "Airplane", "transport/airplane.mp3", "airplane"),
                sound("submarine", "Submarine", "transport/submarine.mp3", "ferry.fill"),
                sound("sailboat", "Sailboat", "transport/sailboat.mp3", "sailboat.fill"),
                sound("rowing-boat", "Rowing Boat", "transport/rowing-boat.mp3", "sailboat.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "things",
            title: "Things",
            systemImageName: "cube.box.fill",
            sounds: [
                sound("keyboard", "Keyboard", "things/keyboard.mp3", "keyboard.fill"),
                sound("typewriter", "Typewriter", "things/typewriter.mp3", "keyboard.fill"),
                sound("paper", "Paper", "things/paper.mp3", "doc.text.fill"),
                sound("clock", "Clock", "things/clock.mp3", "clock.fill"),
                sound("wind-chimes", "Wind Chimes", "things/wind-chimes.mp3", "bell.fill"),
                sound("singing-bowl", "Singing Bowl", "things/singing-bowl.mp3", "circle.fill"),
                sound("ceiling-fan", "Ceiling Fan", "things/ceiling-fan.mp3", "fan.fill"),
                sound("dryer", "Dryer", "things/dryer.mp3", "dryer.fill"),
                sound("slide-projector", "Slide Projector", "things/slide-projector.mp3", "projector.fill"),
                sound("boiling-water", "Boiling Water", "things/boiling-water.mp3", "drop.degreesign.fill"),
                sound("bubbles", "Bubbles", "things/bubbles.mp3", "bubbles.and.sparkles.fill"),
                sound("tuning-radio", "Tuning Radio", "things/tuning-radio.mp3", "radio.fill"),
                sound("morse-code", "Morse Code", "things/morse-code.mp3", "dot.radiowaves.left.and.right"),
                sound("washing-machine", "Washing Machine", "things/washing-machine.mp3", "washer.fill"),
                sound("vinyl-effect", "Vinyl Effect", "things/vinyl-effect.mp3", "record.circle.fill"),
                sound("windshield-wipers", "Windshield Wipers", "things/windshield-wipers.mp3", "car.fill"),
            ]
        ),
        WhiteNoiseCategory(
            id: "noise",
            title: "Noise",
            systemImageName: "waveform",
            sounds: [
                sound("white-noise", "White Noise", "noise/white-noise.wav", "waveform"),
                sound("pink-noise", "Pink Noise", "noise/pink-noise.wav", "waveform"),
                sound("brown-noise", "Brown Noise", "noise/brown-noise.wav", "waveform"),
            ]
        ),
        WhiteNoiseCategory(
            id: "binaural",
            title: "Binaural Beats",
            systemImageName: "waveform.path.ecg",
            sounds: [
                sound("binaural-delta", "Delta", "binaural/binaural-delta.wav", "waveform.path.ecg"),
                sound("binaural-theta", "Theta", "binaural/binaural-theta.wav", "waveform.path.ecg"),
                sound("binaural-alpha", "Alpha", "binaural/binaural-alpha.wav", "waveform.path.ecg"),
                sound("binaural-beta", "Beta", "binaural/binaural-beta.wav", "waveform.path.ecg"),
                sound("binaural-gamma", "Gamma", "binaural/binaural-gamma.wav", "waveform.path.ecg"),
            ]
        ),
        WhiteNoiseCategory(
            id: "utility",
            title: "Utility",
            systemImageName: "slider.horizontal.3",
            sounds: [
                sound("alarm", "Alarm", "alarm.mp3", "alarm.fill"),
                sound("silence", "Silence", "silence.wav", "speaker.slash.fill"),
            ]
        ),
    ]

    static let allSounds: [WhiteNoiseSound] = categories.flatMap(\.sounds)

    static let soundsByID: [String: WhiteNoiseSound] = Dictionary(
        uniqueKeysWithValues: allSounds.map { ($0.id, $0) }
    )

    static func sound(id: String) -> WhiteNoiseSound? {
        soundsByID[id]
    }

    private static func sound(
        _ id: String,
        _ label: String,
        _ relativeSoundPath: String,
        _ systemImageName: String
    ) -> WhiteNoiseSound {
        WhiteNoiseSound(
            id: id,
            label: label,
            resourcePath: "WhiteNoise/sounds/" + relativeSoundPath,
            systemImageName: systemImageName
        )
    }
}
