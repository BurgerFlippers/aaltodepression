import Contacts

nonisolated enum SupportContactsSource {
    static func suggestions() async throws -> [EverydayPerson] {
        let store = CNContactStore()
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            _ = try await store.requestAccess(for: .contacts)
        }
        let status = CNContactStore.authorizationStatus(for: .contacts)
        var allowed = status == .authorized
        if #available(iOS 18, *) { allowed = allowed || status == .limited }
        guard allowed else { return [] }
        return try await Task.detached(priority: .userInitiated) {
            let request = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor])
            request.sortOrder = .givenName
            var people: [EverydayPerson] = []
            try CNContactStore().enumerateContacts(with: request) { contact, _ in
                guard let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty else { return }
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                guard !name.isEmpty else { return }
                let close = isFamilyName(name)
                people.append(EverydayPerson(id: contact.identifier, name: name, phone: phone, role: close ? .close : .friend))
            }
            return people.sorted { a, b in
                if a.role != b.role { return a.role == .close }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }.value
    }

    static func isFamilyName(_ name: String) -> Bool {
        let words = name.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return words.contains { ["äiti", "aiti", "isä", "isa", "mamma", "pappa", "mom", "mum", "mother", "dad", "father"].contains($0) }
    }
}
