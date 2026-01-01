import Foundation

/// Manages FlowGroup operations and screen-to-group associations
class FlowGroupManager {

    /// Create a new flow group
    func createGroup(
        name: String,
        color: FlowGroup.FlowColor,
        screenIds: Set<UUID> = []
    ) -> FlowGroup {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        return FlowGroup(
            name: trimmedName,
            color: color
        )
    }

    /// Update an existing flow group's properties
    func updateGroup(
        _ group: FlowGroup,
        name: String,
        color: FlowGroup.FlowColor
    ) -> FlowGroup {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        return FlowGroup(
            id: group.id,
            name: trimmedName,
            color: color,
            collapsed: group.collapsed
        )
    }

    /// Delete a flow group and remove it from all associated screens
    func deleteGroup(
        groupId: UUID,
        from screens: [CapturedScreen]
    ) -> [CapturedScreen] {
        var updatedScreens = screens

        for i in updatedScreens.indices {
            updatedScreens[i].flowGroupIds.remove(groupId)
        }

        return updatedScreens
    }

    /// Assign a screen to a flow group
    func assignScreenToGroup(
        screenId: UUID,
        groupId: UUID,
        in screens: [CapturedScreen]
    ) -> [CapturedScreen] {
        var updatedScreens = screens

        if let index = updatedScreens.firstIndex(where: { $0.id == screenId }) {
            updatedScreens[index].flowGroupIds.insert(groupId)
        }

        return updatedScreens
    }

    /// Remove a screen from a flow group
    func removeScreenFromGroup(
        screenId: UUID,
        groupId: UUID,
        from screens: [CapturedScreen]
    ) -> [CapturedScreen] {
        var updatedScreens = screens

        if let index = updatedScreens.firstIndex(where: { $0.id == screenId }) {
            updatedScreens[index].flowGroupIds.remove(groupId)
        }

        return updatedScreens
    }

    /// Update all screen assignments for a flow group (bulk operation)
    /// Adds groupId to screens in screenIds, removes from screens not in screenIds
    func updateGroupAssignments(
        groupId: UUID,
        screenIds: Set<UUID>,
        in screens: [CapturedScreen]
    ) -> [CapturedScreen] {
        var updatedScreens = screens

        for i in updatedScreens.indices {
            let screenId = updatedScreens[i].id
            if screenIds.contains(screenId) {
                updatedScreens[i].flowGroupIds.insert(groupId)
            } else {
                updatedScreens[i].flowGroupIds.remove(groupId)
            }
        }

        return updatedScreens
    }

    /// Get all screens associated with a flow group
    func getScreens(
        for groupId: UUID,
        from screens: [CapturedScreen]
    ) -> [CapturedScreen] {
        screens.filter { $0.flowGroupIds.contains(groupId) }
    }

    /// Get all flow groups associated with a screen
    func getGroups(
        for screenId: UUID,
        from groups: [FlowGroup],
        screens: [CapturedScreen]
    ) -> [FlowGroup] {
        guard let screen = screens.first(where: { $0.id == screenId }) else {
            return []
        }

        return groups.filter { screen.flowGroupIds.contains($0.id) }
    }
}
