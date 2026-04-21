//
//  SettingAIView.swift
//  ScriptWidget
//
//  Lets the user configure the OpenAI (or compatible) endpoint used by
//  the AI Generate feature. Values are persisted to the app-group
//  UserDefaults via AISettingsStore.
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

    @State private var showingSavedToast = false

    private enum TestPhase { case idle, running, success, failure }

    private let modelPresets = ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "o4-mini"]

    var body: some View {
        Form {
            Section {
                HStack {
                    if apiKeyVisible {
                        TextField("sk-...", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button {
                        apiKeyVisible.toggle()
                    } label: {
                        Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("API Key")
            } footer: {
                Text("Stored in plain-text UserDefaults on this device. Do not configure on a shared device.")
                    .foregroundColor(.orange)
            }

            Section("Endpoint") {
                TextField("https://api.openai.com", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }

            Section("Model") {
                TextField("gpt-4o-mini", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(modelPresets, id: \.self) { preset in
                            Button(preset) {
                                model = preset
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Agent Loop") {
                Stepper(value: $maxIterations, in: 5...100, step: 5) {
                    HStack {
                        Text("Max Iterations")
                        Spacer()
                        Text("\(maxIterations)")
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", temperature))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $temperature, in: 0.0...1.5, step: 0.05)
                }
            }

            Section {
                Button {
                    runTest()
                } label: {
                    HStack {
                        if testPhase == .running {
                            ProgressView().controlSize(.small)
                        }
                        Text(testButtonLabel)
                    }
                }
                .disabled(testPhase == .running || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if !testMessage.isEmpty {
                    Text(testMessage)
                        .font(.footnote)
                        .foregroundStyle(testPhase == .failure ? Color.red : Color.green)
                }
            } header: {
                Text("Connection")
            }

            Section {
                Button {
                    persist()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFromStore)
        .overlay(alignment: .bottom) {
            if showingSavedToast {
                Text("Saved")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
    }

    private var testButtonLabel: String {
        switch testPhase {
        case .idle:    return "Test Connection"
        case .running: return "Testing..."
        case .success: return "Test Connection"
        case .failure: return "Test Connection"
        }
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
        withAnimation { showingSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showingSavedToast = false }
        }
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
