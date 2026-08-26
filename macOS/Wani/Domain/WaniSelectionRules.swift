import Foundation

enum WaniSelectionDirection {
    case previous
    case next
}

enum WaniSelectionRules {
    static func orderedIDs(in sections: [[UUID]]) -> [UUID] {
        sections.flatMap { $0 }
    }

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

    static func movedID(
        in direction: WaniSelectionDirection,
        selectedIDs: Set<UUID>,
        anchorID: UUID?,
        extending: Bool,
        in orderedIDs: [UUID]
    ) -> UUID? {
        guard !orderedIDs.isEmpty else { return nil }

        let selectedIndices = orderedIDs.indices.filter {
            selectedIDs.contains(orderedIDs[$0])
        }
        let currentIndex: Int
        if extending,
           let anchorID,
           let anchorIndex = orderedIDs.firstIndex(of: anchorID),
           let firstSelectedIndex = selectedIndices.first,
           let lastSelectedIndex = selectedIndices.last {
            currentIndex = anchorIndex == firstSelectedIndex
                ? lastSelectedIndex
                : firstSelectedIndex
        } else if let firstSelectedIndex = selectedIndices.first,
                  let lastSelectedIndex = selectedIndices.last {
            currentIndex = direction == .previous
                ? firstSelectedIndex
                : lastSelectedIndex
        } else {
            return direction == .previous ? orderedIDs.last : orderedIDs.first
        }

        let offset = direction == .previous ? -1 : 1
        let lastIndex = orderedIDs.index(before: orderedIDs.endIndex)
        let targetIndex = min(max(currentIndex + offset, orderedIDs.startIndex), lastIndex)
        return orderedIDs[targetIndex]
    }

    static func boundaryID(
        in direction: WaniSelectionDirection,
        in orderedIDs: [UUID]
    ) -> UUID? {
        direction == .previous ? orderedIDs.first : orderedIDs.last
    }
}
