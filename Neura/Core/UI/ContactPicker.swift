import SwiftUI
import ContactsUI

/// Presents the system contact picker so the user can choose an emergency
/// contact from their phone. Uses property-selection mode so the user taps the
/// exact phone number they want (when a contact has several).
///
/// `CNContactPickerViewController` runs out-of-process, so it requires **no**
/// contacts-permission prompt or `NSContactsUsageDescription` Info.plist key.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    /// Called with the chosen contact's display name and the selected phone number.
    let completion: (_ name: String, _ phoneNumber: String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Drill into phone numbers so the user picks a specific one.
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, completion: completion)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var isPresented: Bool
        let completion: (_ name: String, _ phoneNumber: String) -> Void

        init(isPresented: Binding<Bool>, completion: @escaping (_ name: String, _ phoneNumber: String) -> Void) {
            _isPresented = isPresented
            self.completion = completion
        }

        /// Fired when the user taps a specific phone number of a contact.
        ///
        /// Only the property-level delegate is implemented (not the
        /// contact-level one) — implementing `didSelect contact:` as well would
        /// make the picker select whole contacts and skip number drill-down,
        /// defeating per-number selection.
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            let contact = contactProperty.contact
            let phone = (contactProperty.value as? CNPhoneNumber)?.stringValue ?? ""
            completion(Self.displayName(for: contact), phone)
            isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            isPresented = false
        }

        private static func displayName(for contact: CNContact) -> String {
            let name = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !name.isEmpty { return name }
            return contact.organizationName
        }
    }
}
