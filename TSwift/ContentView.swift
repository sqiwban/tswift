import SwiftUI

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Счётчик: \(count)")
                .font(.largeTitle)
                .monospacedDigit()
                .accessibilityIdentifier("counter")

            Button("Увеличить") {
                count += 1
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("increment")
        }
        .padding()
    }
}
