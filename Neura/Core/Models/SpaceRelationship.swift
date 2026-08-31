import Foundation

extension Space {
    /// Canonical relationship to the account owner. Stored as `rawValue` so
    /// Growth and other child-only features keep working after a language change.
    enum Relationship: String, CaseIterable, Identifiable {
        case child
        case spouse
        case parent
        case sibling
        case other

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .child: return L10n.Profile.Spaces.relationshipChild
            case .spouse: return L10n.Profile.Spaces.relationshipSpouse
            case .parent: return L10n.Profile.Spaces.relationshipParent
            case .sibling: return L10n.Profile.Spaces.relationshipSibling
            case .other: return L10n.Profile.Spaces.relationshipOther
            }
        }

        /// Labels written before relationships were stored canonically.
        var legacyLabels: Set<String> {
            switch self {
            case .child: return [
                "Child", "طفل", "Copil",
                "Son", "Daughter", "Kid", "Baby",
                "ابن", "ابنة", "ولد", "بنت", "طفلة",
                "Fiu", "Fiică", "Băiat", "Fată"
            ]
            case .spouse: return ["Spouse", "زوج/زوجة", "Soț/Soție"]
            case .parent: return ["Parent", "أحد الوالدين", "Părinte"]
            case .sibling: return ["Sibling", "أخ/أخت", "Frate/Soră"]
            case .other: return ["Other", "أخرى", "Altul"]
            }
        }

        static func canonicalize(_ stored: String?) -> Relationship? {
            guard let stored, !stored.isEmpty else { return nil }
            if let match = Relationship(rawValue: stored) { return match }
            return allCases.first { $0.localizedTitle == stored || $0.legacyLabels.contains(stored) }
        }
    }

    var relationshipKind: Relationship? {
        Relationship.canonicalize(relationship)
    }

    /// True when this account should offer the kids growth tracker.
    /// Hidden on the owner's Me profile and on accounts tagged parent/spouse.
    /// Family spaces created before relationship was stored (e.g. "Son")
    /// have `relationship == nil` and still show Growth.
    var showsGrowth: Bool {
        guard !isDefault else { return false }
        switch relationshipKind {
        case .parent, .spouse: return false
        case .child, .sibling, .other, nil: return true
        }
    }

    var isChild: Bool {
        if relationshipKind == .child { return true }
        guard !isDefault, relationshipKind == nil else { return false }
        return Self.nameSuggestsChild(name)
    }

    /// Token match so "Son" counts and "Jason" does not.
    static func nameSuggestsChild(_ name: String) -> Bool {
        let folded = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let tokens = folded.split { $0.isWhitespace || $0 == "-" }.map(String.init)
        let keywords: Set<String> = [
            "son", "daughter", "child", "kid", "baby", "infant", "boy", "girl",
            "طفل", "طفلة", "ابن", "ابنة", "ولد", "بنت",
            "copil", "fiu", "fiica", "baiat", "fata"
        ]
        return tokens.contains { keywords.contains($0) }
    }
}
