//
//  AISettings.swift
//  ScriptWidget
//
//  Persistent configuration for the AI Generate feature.
//
//  Storage model
//  -------------
//  - AIProfile: one provider/model entry. Codable, persisted as JSON in
//    the app-group UserDefaults under `ai.profiles.v2`.
//  - Active profile id under `ai.activeProfileID`.
//  - Agent-loop globals (maxIterations / temperature) are app-wide and
//    live on AISettings.
//  - Legacy single-profile keys (ai.apiKey, ai.baseURL, ai.model) are
//    migrated into a "Default" profile on first load.
//
//  Auth methods per profile:
//    .apiKey  → settings.apiKey holds the literal key.
//    .oauth   → AIOpenAIOAuthVault holds the credential, keyed by the
//               account ID embedded in the access token. settings.apiKey
//               stores the (raw) access token at last sign-in so the
//               vault can find the matching record.
//

import Foundation

enum AIAuthMethod: String, Codable {
    case apiKey
    case oauth
}

struct AIProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var baseURL: String
    var model: String
    var apiKey: String
    var authMethod: AIAuthMethod

    static let defaultBaseURL = "https://api.openai.com"
    static let defaultModel = "gpt-4o-mini"

    static func makeDefault(named name: String = "Default") -> AIProfile {
        AIProfile(
            id: UUID().uuidString,
            name: name,
            baseURL: defaultBaseURL,
            model: defaultModel,
            apiKey: "",
            authMethod: .apiKey
        )
    }

    var isConfigured: Bool {
        switch authMethod {
        case .apiKey:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .oauth:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var normalizedBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AIProfile.defaultBaseURL
        }
        // SwiftOpenAI appends /v1 itself.
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

    var isOpenAIHost: Bool {
        normalizedBaseURL == AIProfile.defaultBaseURL
    }
}

enum AISettingsKey {
    // v2 profile storage
    static let profiles         = "ai.profiles.v2"
    static let activeProfileID  = "ai.activeProfileID"
    // agent-loop globals
    static let maxIterations    = "ai.maxIterations"
    static let temperature      = "ai.temperature"
    // legacy keys (read-only; only used during migration)
    static let legacyAPIKey  = "ai.apiKey"
    static let legacyBaseURL = "ai.baseURL"
    static let legacyModel   = "ai.model"
}

/// Snapshot consumed by AIClient / AgentLoop. Bakes the active profile
/// together with the agent-loop globals.
struct AISettings: Equatable {
    var profile: AIProfile
    var maxIterations: Int
    var temperature: Double

    static let defaultBaseURL = AIProfile.defaultBaseURL
    static let defaultModel = AIProfile.defaultModel
    static let defaultMaxIterations = 20
    static let defaultTemperature = 0.7

    static let `default` = AISettings(
        profile: AIProfile.makeDefault(),
        maxIterations: defaultMaxIterations,
        temperature: defaultTemperature
    )

    var isConfigured: Bool { profile.isConfigured }
    var normalizedBaseURL: String { profile.normalizedBaseURL }

    // Convenience pass-throughs (call sites still read these).
    var apiKey: String { profile.apiKey }
    var baseURL: String { profile.baseURL }
    var model: String { profile.model }
    var authMethod: AIAuthMethod { profile.authMethod }
}

final class AISettingsStore {
    static let shared = AISettingsStore()

    static let changedNotification = Notification.Name("AISettingsStoreChanged")

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "ai.settings.store")

    private init() {
        self.defaults = UserDefaults(suiteName: "group.everettjf.scriptwidget") ?? .standard
        migrateLegacyIfNeeded()
    }

    // MARK: - Profiles

    func loadProfiles() -> [AIProfile] {
        if let data = defaults.data(forKey: AISettingsKey.profiles),
           let decoded = try? JSONDecoder().decode([AIProfile].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        // Should be unreachable after migrate(), but be defensive.
        let fresh = [AIProfile.makeDefault()]
        saveProfiles(fresh, activeID: fresh[0].id, notify: false)
        return fresh
    }

    func loadActiveProfileID() -> String {
        if let stored = defaults.string(forKey: AISettingsKey.activeProfileID),
           !stored.isEmpty {
            return stored
        }
        let profiles = loadProfiles()
        let id = profiles.first?.id ?? ""
        defaults.set(id, forKey: AISettingsKey.activeProfileID)
        return id
    }

    func loadActiveProfile() -> AIProfile {
        let profiles = loadProfiles()
        let activeID = loadActiveProfileID()
        return profiles.first(where: { $0.id == activeID }) ?? profiles.first ?? AIProfile.makeDefault()
    }

    func saveProfiles(_ profiles: [AIProfile], activeID: String? = nil, notify: Bool = true) {
        let data = try? JSONEncoder().encode(profiles)
        defaults.set(data, forKey: AISettingsKey.profiles)
        if let activeID {
            defaults.set(activeID, forKey: AISettingsKey.activeProfileID)
        } else if let current = defaults.string(forKey: AISettingsKey.activeProfileID),
                  !profiles.contains(where: { $0.id == current }) {
            defaults.set(profiles.first?.id ?? "", forKey: AISettingsKey.activeProfileID)
        }
        if notify {
            NotificationCenter.default.post(name: AISettingsStore.changedNotification, object: nil)
        }
    }

    func setActiveProfile(id: String) {
        defaults.set(id, forKey: AISettingsKey.activeProfileID)
        NotificationCenter.default.post(name: AISettingsStore.changedNotification, object: nil)
    }

    func upsertProfile(_ profile: AIProfile) {
        var profiles = loadProfiles()
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        saveProfiles(profiles)
    }

    func deleteProfile(id: String) {
        var profiles = loadProfiles()
        profiles.removeAll(where: { $0.id == id })
        if profiles.isEmpty {
            profiles = [AIProfile.makeDefault()]
        }
        let active = loadActiveProfileID()
        let newActive = profiles.contains(where: { $0.id == active }) ? active : profiles[0].id
        saveProfiles(profiles, activeID: newActive)
    }

    // MARK: - Agent-loop globals

    func loadMaxIterations() -> Int {
        defaults.object(forKey: AISettingsKey.maxIterations) as? Int ?? AISettings.defaultMaxIterations
    }

    func loadTemperature() -> Double {
        defaults.object(forKey: AISettingsKey.temperature) as? Double ?? AISettings.defaultTemperature
    }

    func saveAgentLoop(maxIterations: Int, temperature: Double) {
        defaults.set(maxIterations, forKey: AISettingsKey.maxIterations)
        defaults.set(temperature, forKey: AISettingsKey.temperature)
        NotificationCenter.default.post(name: AISettingsStore.changedNotification, object: nil)
    }

    // MARK: - Combined snapshot for AIClient / AgentLoop

    func load() -> AISettings {
        AISettings(
            profile: loadActiveProfile(),
            maxIterations: loadMaxIterations(),
            temperature: loadTemperature()
        )
    }

    // MARK: - Migration

    private func migrateLegacyIfNeeded() {
        // Already migrated? bail.
        if defaults.data(forKey: AISettingsKey.profiles) != nil {
            return
        }
        let legacyKey = defaults.string(forKey: AISettingsKey.legacyAPIKey) ?? ""
        let legacyBase = defaults.string(forKey: AISettingsKey.legacyBaseURL) ?? AIProfile.defaultBaseURL
        let legacyModel = defaults.string(forKey: AISettingsKey.legacyModel) ?? AIProfile.defaultModel

        let profile = AIProfile(
            id: UUID().uuidString,
            name: "Default",
            baseURL: legacyBase.isEmpty ? AIProfile.defaultBaseURL : legacyBase,
            model: legacyModel.isEmpty ? AIProfile.defaultModel : legacyModel,
            apiKey: legacyKey,
            authMethod: .apiKey
        )

        if let data = try? JSONEncoder().encode([profile]) {
            defaults.set(data, forKey: AISettingsKey.profiles)
        }
        defaults.set(profile.id, forKey: AISettingsKey.activeProfileID)
        // Legacy keys are left in place — harmless. Future writes go to v2.
    }
}
