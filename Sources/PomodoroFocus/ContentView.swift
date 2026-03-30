import SwiftUI

struct ContentView: View {
    var showStorageError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showStorageError {
                StorageErrorBanner()
            }
            Text("PomodoroFocus")
                .font(.largeTitle)
                .padding()
        }
    }
}

struct StorageErrorBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("存储初始化失败，数据将不会保存")
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemYellow).opacity(0.2))
    }
}

#Preview {
    ContentView()
}
