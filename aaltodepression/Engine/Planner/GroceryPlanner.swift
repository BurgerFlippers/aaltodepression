import Foundation

/// A shopping list for the next three or four days, built on the plate model:
/// half vegetables, a quarter protein, a quarter whole grains. No calories, just variety.
nonisolated enum GroceryPlanner {
    static let regular: [GroceryItem] = [
        .init(name: "Tomatoes", group: .vegetables), .init(name: "Cucumber", group: .vegetables),
        .init(name: "Carrots", group: .vegetables), .init(name: "Frozen broccoli", group: .vegetables),
        .init(name: "Apples", group: .vegetables), .init(name: "Frozen blueberries", group: .vegetables),
        .init(name: "Salmon", group: .protein), .init(name: "Eggs", group: .protein),
        .init(name: "Cottage cheese", group: .protein), .init(name: "Canned chickpeas", group: .protein),
        .init(name: "Rye bread", group: .carbs), .init(name: "Oats", group: .carbs),
        .init(name: "Potatoes", group: .carbs),
        .init(name: "Rapeseed oil", group: .staples), .init(name: "Milk or oat drink", group: .staples),
    ]

    /// For heavier days: things that keep and need almost no cooking.
    static let easy: [GroceryItem] = [
        .init(name: "Frozen vegetable mix", group: .vegetables), .init(name: "Bananas", group: .vegetables),
        .init(name: "Frozen berries", group: .vegetables), .init(name: "Cucumber", group: .vegetables),
        .init(name: "Ready-cooked lentil soup", group: .protein), .init(name: "Eggs", group: .protein),
        .init(name: "Cottage cheese", group: .protein), .init(name: "Canned tuna", group: .protein),
        .init(name: "Rye bread", group: .carbs), .init(name: "Instant oats", group: .carbs),
        .init(name: "Microwave rice", group: .carbs),
        .init(name: "Milk or oat drink", group: .staples),
    ]

    static func list(for capacity: Capacity) -> [GroceryItem] {
        capacity == .low ? easy : regular
    }

    /// One easy plate for today, by capacity.
    static func plate(for capacity: Capacity, day: Day) -> String {
        let tired = ["Rye bread, cottage cheese and cucumber", "Oat porridge with berries and an egg",
                     "Lentil soup with rye bread", "Microwave rice, tuna and frozen vegetables"]
        let regular = ["Salmon, potatoes and a big salad", "Chickpea curry with rice and vegetables",
                       "Omelette, rye bread and tomatoes", "Oven vegetables with eggs and potatoes"]
        let pool = capacity == .low ? tired : regular
        return pool[((day.jdn % pool.count) + pool.count) % pool.count]
    }
}
