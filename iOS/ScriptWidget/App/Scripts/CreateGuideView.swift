//
//  CreateGuideView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/1/3.
//

import SwiftUI


class CreateGuideDataObject: ObservableObject {
    @Published var models = [ScriptModel]()

    init() {
        
        
        DispatchQueue.global().async { [self] in
            var items = ScriptManager.listBundleScripts(bundle: "Script", relativePath: "template")
            if let index = items.firstIndex(where: { (model) -> Bool in
                return model.name == "Empty Script"
            }) {
                items.move(fromOffsets: [index], toOffset: 0)
            }
            
            DispatchQueue.main.async {
                self.models = items
            }
        }
        
    }
}


struct CreateGuideView: View {
    @ObservedObject var dataObject = CreateGuideDataObject()

    @Environment(\.presentationMode) var presentationMode

    @State private var showingAIGenerate = false
    @State private var showingAIConfigAlert = false

    var body: some View {
        NavigationView {
            List {
                aiRow

                ForEach(dataObject.models) { item in
                    NavigationLink(destination: ScriptCodeEditorView(mode: .creator,scriptModel:item, actionCreate: {
                        // create
                        guard let content = item.package.readMainFile().0 else { return }

                        // image copy path
                        let imageCopyPath = item.package.imagePath

                        _ = sharedScriptManager.createScript(content: content, recommendPackageName: item.name, imageCopyPath: imageCopyPath)

                        NotificationCenter.default.post(name: ScriptWidgetHomeViewDataObject.scriptCreateNotification, object: nil)

                        // dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                            self.presentationMode.wrappedValue.dismiss()
                        })
                    })) {
                        WidgetRowView(model: item)
                    }
                }
            }
            .navigationBarTitle(Text("Create from template"), displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .background(
                NavigationLink(isActive: $showingAIGenerate) {
                    AIGenerateView()
                } label: { EmptyView() }
                .hidden()
            )
            .alert("Configure AI First", isPresented: $showingAIConfigAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Open Settings → AI to add your OpenAI API key, then come back to generate with AI.")
            }
        }
    }

    private var aiRow: some View {
        Button {
            if AISettingsStore.shared.load().isConfigured {
                showingAIGenerate = true
            } else {
                showingAIConfigAlert = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate with AI")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Describe your widget and let the AI build it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CreateGuideView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGuideView()
    }
}
