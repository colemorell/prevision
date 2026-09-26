import SwiftUI

struct InnerDisplayView: View {
    var body: some View {
        VStack(spacing: 0) {
            ClientView()
            DesignerView()
        }
        .ignoresSafeArea()
    }
}
