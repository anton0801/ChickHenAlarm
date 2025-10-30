
import SwiftUI
import AVFoundation

struct SoundsView: View {
    @State private var engine = AVAudioEngine()
    @State private var players: [AVAudioPlayerNode] = [] // До 4
    @State private var volume: Float = 0.5 // Добавлена переменная для слайдера
    
    var body: some View {
        VStack {
            Button("Играть сцену") { playScene() }
            Slider(value: $volume) // Теперь $volume определена
        }
        .navigationTitle("Звуки")
    }
    
    func playScene() {
        // Пример: "Деревня утром" — микс петуха + природа
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        // Добавь players, connect и start
        // White noise: AVAudioPlayerNode с буфером
        // Установка громкости: mixer.volume = volume
    }
}
