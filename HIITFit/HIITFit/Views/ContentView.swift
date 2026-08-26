import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 9

    var body: some View {
        TabView(selection: $selectedTab) {
            WelcomeView(selectedTab: $selectedTab)
                .tag(9)

            ForEach(
                Exercise.exercises.indices,
                id: \.self
            ) { index in
                ExerciseView(
                    selectedTab: $selectedTab,
                    index: index
                )
                .tag(index)
            }
        }
        .tabViewStyle(
            PageTabViewStyle(indexDisplayMode: .never)
        )
    }
}
