import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 60
    @AppStorage("codexCLIPath") private var codexCLIPath: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Refresh interval")
                    Spacer()
                    Text("\(Int(refreshInterval))s")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: $refreshInterval,
                    in: 10...300,
                    step: 10
                ) {
                    Text("Refresh interval")
                } minimumValueLabel: {
                    Text("10s")
                } maximumValueLabel: {
                    Text("300s")
                }
            }

            Section {
                TextField("Codex CLI path (auto-detect if empty)", text: $codexCLIPath)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Codex CLI")
            } footer: {
                Text("Leave blank to auto-detect codex from PATH and common install locations.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
        .padding()
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
