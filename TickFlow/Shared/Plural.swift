import Foundation

/// Русские формы слов после числа: 1 день, 2 дня, 5 дней.
enum Plural {
    static func form(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return one }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return few }
        return many
    }

    static func days(_ n: Int) -> String { form(n, "день", "дня", "дней") }
    static func times(_ n: Int) -> String { form(n, "раз", "раза", "раз") }
    static func tasks(_ n: Int) -> String { form(n, "задача", "задачи", "задач") }
    static func habits(_ n: Int) -> String { form(n, "привычки", "привычек", "привычек") }
}
