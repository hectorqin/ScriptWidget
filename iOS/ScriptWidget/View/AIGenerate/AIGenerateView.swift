//
//  AIGenerateView.swift
//  ScriptWidget
//
//  Prompt input → agent loop → review. The session object lives for
//  the duration of this view (including nested refines).
//

import SwiftUI

struct AIGenerateView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var session = AIGenerateSession()

    @State private var prompt: String = ""
    @State private var showReview = false

    private let placeholderPrompt = "e.g. Show the current weather for my location, with a minimalist dark background."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    Text("Describe your widget")
                        .font(.headline)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .frame(minHeight: 120)
                            .padding(4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(10)
                        if prompt.isEmpty {
                            Text(placeholderPrompt)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                                .padding(.leading, 10)
                                .allowsHitTesting(false)
                        }
                    }
                }

                Picker("Size", selection: $session.size) {
                    ForEach(AIWidgetSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    session.start(userDescription: prompt)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(session.isRunning ? "Generating..." : "Generate")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if session.isRunning || hasOutcome {
                    AIGenerateProgressView(session: session)
                }
            }
            .padding()
        }
        .navigationTitle("Generate")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: session.phase) { newPhase in
            if case .done = newPhase {
                showReview = true
            } else if case .exhausted = newPhase {
                showReview = true
            }
        }
        .background(
            NavigationLink(isActive: $showReview) {
                AIReviewView(session: session) {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: { EmptyView() }
            .hidden()
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Widget Generator")
                    .font(.title3.weight(.semibold))
                Text("Describe what you want; the AI will iterate until the widget runs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var hasOutcome: Bool {
        switch session.phase {
        case .idle: return false
        default: return true
        }
    }
}
