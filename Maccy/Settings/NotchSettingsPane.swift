import SwiftUI
import Defaults
import Settings

struct NotchSettingsPane: View {
  @Default(.notchShelfEnabled) private var notchShelfEnabled
  @Default(.notchActivationThreshold) private var activationThreshold
  @Default(.notchDeactivationThreshold) private var deactivationThreshold
  @Default(.notchHorizontalZone) private var horizontalZone

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(title: "", bottomDivider: true) {
        Toggle(isOn: $notchShelfEnabled) {
          Text("Enable notch shelf", tableName: "NotchSettings")
        }
        .onChange(of: notchShelfEnabled) { _ in
          applySettings()
        }

        Text("Shows recent clipboard items when hovering near the top center of the screen.",
             tableName: "NotchSettings")
          .foregroundStyle(.secondary)
          .font(.caption)
      }

      Settings.Section(label: { Text("Activation", tableName: "NotchSettings") }) {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Distance from top:", tableName: "NotchSettings")
            Slider(value: $activationThreshold, in: 1...30, step: 1)
              .frame(width: 120)
            Text("\(Int(activationThreshold)) px")
              .monospacedDigit()
              .frame(width: 40, alignment: .trailing)
          }

          HStack {
            Text("Hide threshold:", tableName: "NotchSettings")
            Slider(value: $deactivationThreshold, in: 50...400, step: 10)
              .frame(width: 120)
            Text("\(Int(deactivationThreshold)) px")
              .monospacedDigit()
              .frame(width: 40, alignment: .trailing)
          }

          HStack {
            Text("Horizontal zone:", tableName: "NotchSettings")
            Slider(value: $horizontalZone, in: 0.05...0.5, step: 0.05)
              .frame(width: 120)
            Text("\(Int(horizontalZone * 100))%")
              .monospacedDigit()
              .frame(width: 40, alignment: .trailing)
          }
        }
        .disabled(!notchShelfEnabled)
        .onChange(of: activationThreshold) { _ in applySettings() }
        .onChange(of: deactivationThreshold) { _ in applySettings() }
        .onChange(of: horizontalZone) { _ in applySettings() }
      }

      Settings.Section(title: "") {
        Text("Changes take effect immediately.", tableName: "NotchSettings")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
    }
  }

  private func applySettings() {
    if notchShelfEnabled {
      NotchHoverDetector.shared.updateThresholds(
        activation: activationThreshold,
        deactivation: deactivationThreshold,
        horizontalZone: horizontalZone
      )
    }
    if !notchShelfEnabled {
      NotchHoverDetector.shared.stop()
    } else {
      NotchHoverDetector.shared.start()
    }
  }
}

#Preview {
  NotchSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
