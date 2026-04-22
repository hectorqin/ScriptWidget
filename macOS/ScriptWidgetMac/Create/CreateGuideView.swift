//
//  CreateGuideView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/18.
//

import SwiftUI

let defaultCreateScriptContent = """

//
// ScriptWidget
// https://xnu.app/scriptwidget
//
//

// widget-size : large,medium,small
const widget_size = $getenv("widget-size");

// parameter
const widget_param = $getenv("widget-param");

$render(
  <vstack frame="max">
    <text font="title">Hello New Widget</text>
    <text font="caption">{widget_size}</text>
    <text font="caption">{widget_param}</text>
  </vstack>
);

"""

struct CreateGuideView: View {
    @Environment(\.dismiss) var dismiss

    @State var enteredText: String = "A New Widget"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            aiCard

            Divider()

            Text("Or start from a blank widget")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Script name")
                    .font(.headline)
                TextField("", text: $enteredText)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Blank") {
                    createBlank()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 420)
        .padding(16)
    }

    private var aiCard: some View {
        Button {
            dismiss()
            // Hand off to SidebarView's notification listener so we
            // reuse the "configure AI first" alert path.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(
                    name: AIGenerateWindowView.openRequestNotification,
                    object: nil
                )
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate with AI")
                        .font(.headline)
                    Text("Describe your widget and let the AI build it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createBlank() {
        let inputText = enteredText.trim()
        if inputText.isEmpty {
            MacKitUtil.alertWarn(title: "Invalid name", message: "Name can not be empty")
            return
        }

        if !inputText.checkIfValidFileName() {
            MacKitUtil.alertWarn(title: "Invalid name", message: "Please make sure the widget name is an valid file name")
            return
        }

        let scriptName = inputText
        let result = sharedScriptManager.createScript(
            content: defaultCreateScriptContent,
            recommendPackageName: scriptName,
            imageCopyPath: nil
        )

        if !result.0 {
            print("Create failed : \(result.1)")
            MacKitUtil.alertWarn(title: "Create failed", message: "Please retry or relaunch app :)\nError : \(result.1)")
            return
        }

        NotificationCenter.default.post(name: SharedAppStore.scriptCreateNotification, object: nil)

        dismiss()
    }
}

struct CreateGuideView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGuideView()
    }
}
