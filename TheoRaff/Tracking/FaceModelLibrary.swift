import RealityKit

/// Loads face models (glasses and hats) once and hands out copies, so swiping between
/// looks swaps them straight away instead of reading the USDZ again each time.
@MainActor
final class FaceModelLibrary {
    private var loaded: [String: Entity] = [:]
    private var pending: [String: Task<Entity?, Never>] = [:]

    /// A fresh copy of a model that has already loaded, or nil if it hasn't yet.
    func copy(of name: String) -> Entity? {
        loaded[name]?.clone(recursive: true)
    }

    /// A fresh copy of the model, loading it first if needed. Nil if it can't be loaded.
    func load(_ name: String) async -> Entity? {
        if let model = copy(of: name) {
            return model
        }
        let task = pending[name] ?? Task {
            do {
                return try await Entity(named: name)
            } catch {
                print("Could not load face model \(name): \(error)")
                return nil
            }
        }
        pending[name] = task
        let model = await task.value
        pending[name] = nil
        if let model, loaded[name] == nil {
            loaded[name] = model
        }
        return copy(of: name)
    }

    /// Starts loading models in the background, for example every model in the deck.
    func preload(_ names: [String]) {
        for name in Set(names) where loaded[name] == nil && pending[name] == nil {
            Task { _ = await load(name) }
        }
    }
}
