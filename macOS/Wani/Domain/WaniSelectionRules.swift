import Foundation

enum WaniSelectionRules {
    static func range(
        from anchorID: UUID?,
        through targetID: UUID,
        in orderedIDs: [UUID]
    ) -> Set<UUID> {
        guard
            let anchorID,
            let anchorIndex = orderedIDs.firstIndex(of: anchorID),
            let targetIndex = orderedIDs.firstIndex(of: targetID)
        else {
            return [targetID]
        }

        let bounds = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        return Set(bounds.map { orderedIDs[$0] })
    }
}
