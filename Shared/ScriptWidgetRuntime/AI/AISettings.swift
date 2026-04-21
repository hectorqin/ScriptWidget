//
//  AISettings.swift
//  ScriptWidget
//
//  Persistent configuration for the AI Generate feature.
//  Stored in the app-group UserDefaults so both iOS and macOS main apps
//  (and potentially extensions) share the same values.
//
//  Security note: API key is stored in plain-text UserDefaults in this
//  initial revision. A Keychain migration is planned.
//

import Foundation

enum AISettingsKey {
    static let apiKey        = "ai.apiKey"
    static let baseURL       = "ai.baseURL"
    static let model         = "ai.model"
    static let maxIterations = "ai.maxIterations"
    static let temperature   = "ai.temperature"
}

struct AISettings: Equatable {
    var apiKey: String
    var baseURL: String
    var model: String
    var maxIterations: Int
    var temperature: Double

    static let defaultBaseURL = "https://api.openai.com"
    static let defaultModel = "gpt-4o-mini"
    static let defaultMaxIterations = 20
    static let defaultTemperature = 0.7

    static let `default` = AISettings(
        apiKey: "",
        baseURL: defaultBaseURL,
        model: defaultModel,
        maxIterations: defaultMaxIterations,
        temperature: defaultTemperature
    )

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AISettings.defaultBaseURL
        }
        // Strip trailing /v1 or / — SwiftOpenAI appends /v1 itself.
        var normalized = trimmed
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        if normalized.hasSuffix("/v1") {
            normalized.removeLast(3)
        }
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }
}

final class AISettingsStore {
    static let shared = AISettingsStore()

    static let changedNotification = Notification.Name("AISettingsStoreChanged")

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults(suiteName: "group.everettjf.scriptwidget") ?? .standard
    }

    func load() -> AISettings {
        let apiKey = defaults.string(forKey: AISettingsKey.apiKey) ?? ""
        let baseURL = defaults.string(forKey: AISettingsKey.baseURL) ?? AISettings.defaultBaseURL
        let model = defaults.string(forKey: AISettingsKey.model) ?? AISettings.defaultModel

        let storedIterations = defaults.object(forKey: AISettingsKey.maxIterations) as? Int
        let maxIterations = storedIterations ?? AISettings.defaultMaxIterations

        let storedTemperature = defaults.object(forKey: AISettingsKey.temperature) as? Double
        let temperature = storedTemperature ?? AISettings.defaultTemperature

        return AISettings(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            maxIterations: maxIterations,
            temperature: temperature
        )
    }

    func save(_ settings: AISettings) {
        defaults.set(settings.apiKey, forKey: AISettingsKey.apiKey)
        defaults.set(settings.baseURL, forKey: AISettingsKey.baseURL)
        defaults.set(settings.model, forKey: AISettingsKey.model)
        defaults.set(settings.maxIterations, forKey: AISettingsKey.maxIterations)
        defaults.set(settings.temperature, forKey: AISettingsKey.temperature)
        NotificationCenter.default.post(name: AISettingsStore.changedNotification, object: nil)
    }
}
