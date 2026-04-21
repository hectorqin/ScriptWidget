//
//  SettingAIView.swift
//  ScriptWidgetMac
//
//  macOS-flavored AI configuration panel, hosted inside the standard
//  Settings scene (Cmd+,).
//

import SwiftUI

struct SettingAIView: View {
    @State private var apiKey: String = ""
    @State private var baseURL: String = AISettings.defaultBaseURL
    @State private var model: String = AISettings.defaultModel
    @State private var maxIterations: Int = AISettings.defaultMaxIterations
    @State private var temperature: Double = AISettings.defaultTemperature
    @State private var apiKeyVisible: Bool = false

    @State private var testPhase: TestPhase = .idle
    @State private var testMessage: String = ""

    private enum TestPhase { case idle, running, success, failure }

    private let modelPresets = ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "o4-mini"]

    var body: some View {
        Form {
            Section("API Key") {
                HStack {
                    Group {
                        if apiKeyVisible {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        apiKeyVisible.toggle()
                    } label: {
                        Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                Text("Stored in plain-text UserDefaults on this device. Do not configure on a shared device.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Section("Endpoint") {
                TextField("https://api.openai.com", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Model") {
                TextField("gpt-4o-mini", text: $model)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 6) {
                    ForEach(modelPresets, id: \.self) { preset in
                        Button(preset) { model = preset }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }

            Section("Agent Loop") {
                Stepper(value: $maxIterations, in: 5...100, step: 5) {
                    Text("Max Iterations: \(maxIterations)")
                }
                HStack {
                    Text("Temperature")
                    Slider(value: $temperature, in: 0.0...1.5, step: 0.05)
                    Text(String(format: "%.2f", temperature))
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Section("Connection") {
                HStack {
                    Button {
                        runTest()
                    } label: {
                        HStack {
                            if testPhase == .running {
                                ProgressView().controlSize(.small)
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(testPhase == .running || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !testMessage.isEmpty {
                        Text(testMessage)
                            .font(.footnote)
                            .foregroundStyle(testPhase == .failure ? Color.red : Color.green)
                    }
                    Spacer()
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        persist()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(minWidth: 520, minHeight: 520)
        .onAppear(perform: loadFromStore)
    }

    private func loadFromStore() {
        let s = AISettingsStore.shared.load()
        apiKey = s.apiKey
        baseURL = s.baseURL
        model = s.model
        maxIterations = s.maxIterations
        temperature = s.temperature
    }

    private func persist() {
        let settings = AISettings(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            maxIterations: maxIterations,
            temperature: temperature
        )
        AISettingsStore.shared.save(settings)
    }

    private func runTest() {
        persist()
        let settings = AISettingsStore.shared.load()
        testPhase = .running
        testMessage = ""
        Task {
            do {
                let messages = [
                    AIMessage(role: .system, content: "You reply with exactly: pong"),
                    AIMessage(role: .user, content: "ping"),
                ]
                let result = try await AIClient.shared.chat(messages: messages, settings: settings)
                await MainActor.run {
                    testPhase = .success
                    testMessage = "OK — \(result.content.prefix(60)) (\(result.usage.totalTokens) tokens)"
                }
            } catch {
                await MainActor.run {
                    testPhase = .failure
                    testMessage = error.localizedDescription
                }
            }
        }
    }
}
