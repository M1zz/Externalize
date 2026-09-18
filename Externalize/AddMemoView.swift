import SwiftUI
import UIKit

struct AddMemoView: View {
    @Environment(MemoModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: MemoKind = .parking
    @State private var value = ""
    @State private var label = ""
    @State private var lifetime: MemoLifetime = .standard
    @FocusState private var isValueFocused: Bool

    private var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MemoKind.allCases) { option in
                                KindChip(kind: option, isSelected: option == kind) {
                                    kind = option
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }

                Section("What to remember") {
                    TextField(kind.placeholder, text: $value)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .keyboardType(kind.prefersNumericKeyboard ? .numbersAndPunctuation : .default)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isValueFocused)
                        .submitLabel(.done)
                        .onSubmit(save)

                    TextField("Label (optional)", text: $label)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Picker("Forget after", selection: $lifetime) {
                        ForEach(MemoLifetime.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Forget after")
                } footer: {
                    Text("It deletes itself. No archive, no history.")
                }
            }
            .navigationTitle("Remember")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedValue.isEmpty)
                }
            }
            .onAppear { isValueFocused = true }
        }
        .presentationDetents([.large])
    }

    private func save() {
        guard !trimmedValue.isEmpty else { return }
        model.add(kind: kind, label: label, value: trimmedValue, lifetime: lifetime)
        dismiss()
    }
}

struct KindChip: View {
    let kind: MemoKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(kind.title, systemImage: kind.symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AddMemoView()
        .environment(MemoModel())
}
