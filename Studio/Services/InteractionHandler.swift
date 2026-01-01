import Foundation

@MainActor
class InteractionHandler {
    /// Generic method to handle any interaction and capture results
    /// - Parameters:
    ///   - coordinator: The interaction coordinator to use
    ///   - errorMessage: Message to use if interaction fails
    ///   - action: The async interaction action to perform
    /// - Returns: The interaction result if successful, nil otherwise
    func handleInteraction(
        coordinator: InteractionCoordinator?,
        errorMessage: String,
        onError: (String) -> Void,
        action: (InteractionCoordinator) async throws -> InteractionCoordinator.InteractionResult
    ) async -> InteractionCoordinator.InteractionResult? {
        guard let coordinator = coordinator else {
            return nil
        }

        do {
            return try await action(coordinator)
        } catch {
            onError("\(errorMessage): \(error.localizedDescription)")
            return nil
        }
    }
}
