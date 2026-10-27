import SwiftUI

struct SettingsView: View {
    @AppStorage(EasyTODOSettings.launchAtLogin) private var launchAtLogin = false
    @AppStorage(EasyTODOSettings.alwaysOnTop) private var alwaysOnTop = true
    @AppStorage(EasyTODOSettings.showMenuBar) private var showMenuBar = true
    @AppStorage(EasyTODOSettings.hiddenDockIcon) private var hiddenDockIcon = false
    @AppStorage(EasyTODOSettings.transparency) private var transparency = 0.80
    @AppStorage(EasyTODOSettings.theme) private var theme = ThemeOption.light.rawValue
    @AppStorage(EasyTODOSettings.textScale) private var textScale = TextSize.defaultScale
    @AppStorage(EasyTODOSettings.dayBoundaryMinutes) private var dayBoundaryMinutes = TaskDayBoundary.defaultMinutes

    @State private var loginItemMessage: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                Toggle("Always on Top", isOn: $alwaysOnTop)
                Toggle("Show in Menu Bar", isOn: $showMenuBar)
                Toggle("Hide Dock Icon", isOn: $hiddenDockIcon)
                    .disabled(!showMenuBar)

                Text("Quick Add: \(GlobalShortcutManager.quickAddShortcutDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let loginItemMessage {
                    Text(loginItemMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Day Boundary") {
                DatePicker("每日分界时间", selection: boundaryTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .environment(\.locale, Locale(identifier: "en_GB"))
                    .accessibilityIdentifier("dayBoundaryTime")

                Text("每天 \(boundaryLabel) 开始新的一天；此前仍算前一天。用于今天的列表、快捷新增和未完成任务顺延，自动保存。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Text Size") {
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int((textScale * 100).rounded()))%")
                        .monospacedDigit()
                    Button("Reset") {
                        textScale = TextSize.defaultScale
                    }
                    .disabled(abs(textScale - TextSize.defaultScale) < 0.001)
                }

                Slider(value: $textScale, in: TextSize.range, step: 0.05) {
                    Text("Text size")
                } minimumValueLabel: {
                    Text("85%")
                } maximumValueLabel: {
                    Text("160%")
                }
                .accessibilityValue("\(Int((textScale * 100).rounded())) percent")

                Text("Your tasks, easier to read · 待办事项")
                    .font(.system(size: TextSize.scaled(15, by: textScale)))
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Applies to task lists, hover previews, widgets, and task inputs. Saved automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Opacity") {
                WindowOpacityControl(value: $transparency)
            }

            Section("Theme") {
                Picker("Theme", selection: $theme) {
                    ForEach(ThemeOption.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
        .onChange(of: dayBoundaryMinutes) { _, _ in
            TaskDayClock.shared.refresh()
        }
        .onChange(of: launchAtLogin) { _, newValue in
            loginItemMessage = LoginItemManager.setEnabled(newValue)
        }
        .onChange(of: alwaysOnTop) { _, _ in
            WindowManager.shared.applyWindowSettings()
        }
        .onChange(of: transparency) { _, _ in
            WindowManager.shared.applyWindowSettings()
        }
        .onChange(of: textScale) { _, _ in
            MenuBarManager.shared.applyTextSize()
            WidgetWindowManager.shared.applyTextSize()
        }
        .onChange(of: showMenuBar) { _, newValue in
            if !newValue {
                hiddenDockIcon = false
            }

            WindowManager.shared.applyActivationPolicy()
        }
        .onChange(of: hiddenDockIcon) { _, _ in
            WindowManager.shared.applyActivationPolicy()
        }
    }

    private var boundaryLabel: String {
        String(format: "%02d:%02d", dayBoundaryMinutes / 60, dayBoundaryMinutes % 60)
    }

    private var boundaryTime: Binding<Date> {
        Binding {
            Date(timeIntervalSince1970: TimeInterval(dayBoundaryMinutes * 60))
        } set: { date in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            dayBoundaryMinutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        }
    }
}
