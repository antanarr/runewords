import SwiftUI

struct DevToolsView: View {
    @StateObject private var levelService = LevelService.shared
    @State private var isReloading = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Catalog Information") {
                    HStack {
                        Text("Source")
                        Spacer()
                        Text(levelService.currentCatalogSource.rawValue)
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(levelService.catalogVersion)
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Total Levels")
                        Spacer()
                        Text("\(levelService.totalLevelCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button(action: reloadCatalog) {
                        HStack {
                            Label("Reload Catalog", systemImage: "arrow.clockwise")
                            Spacer()
                            if isReloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isReloading)
                    
                    Button(action: clearCache) {
                        Label("Clear Level Cache", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
                
                Section("Remote Config") {
                    Text("TODO: Add Remote Config switch for levels_source")
                        .foregroundStyle(.secondary)
                        .italic()
                }
                
                Section("Debug Info") {
                    if let currentLevel = levelService.currentLevel {
                        HStack {
                            Text("Current Level ID")
                            Spacer()
                            Text("\(currentLevel.id)")
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Realm")
                            Spacer()
                            Text(currentLevel.realm ?? "—")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Base Letters")
                            Spacer()
                            Text(currentLevel.baseLetters)
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Dev Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay(alignment: .top) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
            }
        }
        .animation(.easeInOut, value: showToast)
    }
    
    private func reloadCatalog() {
        isReloading = true
        Task {
            await levelService.reloadCatalog()
            await MainActor.run {
                isReloading = false
                toastMessage = "Catalog reloaded successfully"
                showToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        }
    }
    
    private func clearCache() {
        levelService.clearCache()
        toastMessage = "Cache cleared"
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
            )
            .shadow(radius: 5)
    }
}

#Preview {
    DevToolsView()
}
