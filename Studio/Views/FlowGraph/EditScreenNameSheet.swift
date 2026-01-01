import SwiftUI

struct EditScreenNameSheet: View {
    @ObservedObject var viewModel: RecordingSessionViewModel
    let screenId: UUID
    @Binding var isPresented: Bool

    @State private var screenName: String = ""

    var screen: CapturedScreen? {
        viewModel.capturedScreens.first { $0.id == screenId }
    }

    var canSave: Bool {
        !screenName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Screen Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let screenshot = screen?.screenshot {
                            Image(nsImage: screenshot)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .cornerRadius(8)
                        }
                    }
                }

                Section("Name") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Screen Name")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Enter screen name", text: $screenName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)

                        Button {
                            saveChanges()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Save")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Screen Name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
        .onAppear {
            screenName = screen?.name ?? ""
        }
    }

    private func saveChanges() {
        guard canSave else { return }

        if let index = viewModel.capturedScreens.firstIndex(where: { $0.id == screenId }) {
            let newName = screenName.trimmingCharacters(in: .whitespaces)
            viewModel.capturedScreens[index].name = newName
        }

        isPresented = false
    }
}
