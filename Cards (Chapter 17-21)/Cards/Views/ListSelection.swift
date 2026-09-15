import SwiftUI

enum ListState {
    case list
    case carousel
}

struct ListSelection: View {
    @Binding var listState: ListState

    var body: some View {
        Picker(
            selection: $listState,
            label: Text("")
        ) {
            Image(
                systemName:
                    "square.grid.2x2.fill"
            )
            .tag(ListState.list)

            Image(
                systemName:
                    "rectangle.stack.fill"
            )
            .tag(ListState.carousel)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}

#Preview {
    ListSelection(
        listState: .constant(.list)
    )
}
