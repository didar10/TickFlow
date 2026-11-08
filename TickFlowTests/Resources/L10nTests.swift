import Foundation
import Testing
@testable import TickFlow

/// Каталог строк читается из исходников (`#filePath`): тесты идут в симуляторе, у которого есть доступ
/// к файлам Mac. Скомпилированные переводы берутся из бандла приложения.
struct L10nTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Resources
        .deletingLastPathComponent() // TickFlowTests
        .deletingLastPathComponent() // корень репозитория

    static let languages = ["ru", "en"]

    /// Ключи из `String(localized: "…"` в L10n.swift.
    static let keys: [String] = {
        let url = root.appending(path: "TickFlow/Resources/L10n.swift")
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let regex = /String\(localized:\s*"([^"]+)"/
        return source.matches(of: regex).map { String($0.output.1) }
    }()

    /// `strings` из Localizable.xcstrings.
    nonisolated(unsafe) static let catalog: [String: Any] = {
        let url = root.appending(path: "TickFlow/Resources/Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any]
        else { return [:] }
        return strings
    }()

    /// Все варианты перевода ключа на язык: одна строка или формы множественного числа.
    static func values(_ key: String, _ language: String) -> [String: String] {
        guard let entry = catalog[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any]
        else { return [:] }
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return ["": value]
        }
        var result: [String: String] = [:]
        if let variations = localization["variations"] as? [String: [String: Any]] {
            for (_, forms) in variations {
                for (form, body) in forms {
                    if let body = body as? [String: Any],
                       let unit = body["stringUnit"] as? [String: Any],
                       let value = unit["value"] as? String {
                        result[form] = value
                    }
                }
            }
        }
        return result
    }

    /// Плейсхолдеры строки по позициям: `%@ и %lld` → [1: "@", 2: "lld"].
    static func placeholders(_ value: String) -> [Int: String] {
        var result: [Int: String] = [:]
        var next = 1
        for match in value.matches(of: /%(?:(\d+)\$)?(lld|ld|d|@|f|\.\d+f)/) {
            let position = match.output.1.flatMap { Int($0) } ?? next
            result[position] = String(match.output.2)
            next = position + 1
        }
        return result
    }

    @Test func sourcesAreReadable() {
        #expect(Self.keys.count > 300)
        #expect(Self.catalog.count >= Self.keys.count)
    }

    @Test func everyKeyIsTranslatedToAllLanguages() {
        for key in Self.keys {
            #expect(Self.catalog[key] != nil, "Нет ключа в каталоге: \(key)")
            for language in Self.languages {
                let values = Self.values(key, language)
                #expect(!values.isEmpty, "Нет перевода \(language): \(key)")
                #expect(!values.values.contains(""), "Пустой перевод \(language): \(key)")
            }
        }
    }

    @Test func keysAreUnique() {
        let duplicates = Dictionary(grouping: Self.keys, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(duplicates.isEmpty, "Ключи повторяются: \(duplicates.sorted())")
    }

    @Test func placeholdersMatchAcrossLanguages() {
        for key in Self.keys {
            let ru = Self.values(key, "ru")
            let en = Self.values(key, "en")
            guard let reference = ru["other"] ?? ru[""] else { continue }
            let expected = Self.placeholders(reference)
            for (form, value) in ru.merging(en.mapKeys { "en.\($0)" }, uniquingKeysWith: { a, _ in a }) {
                let actual = Self.placeholders(value)
                // Форма «one» может обходиться без числа («a day»), но не может добавить чужих аргументов.
                if form.hasSuffix("one") {
                    #expect(actual.allSatisfy { expected[$0.key] == $0.value }, "\(key) [\(form)]: \(value)")
                } else {
                    #expect(actual == expected, "\(key) [\(form)]: \(value) ≠ \(reference)")
                }
            }
        }
    }

    // MARK: - Множественное число

    private func plural(_ key: String, _ count: Int, language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: Locale(identifier: language), count)
    }

    @Test(arguments: [
        (1, "1 день"), (2, "2 дня"), (5, "5 дней"), (11, "11 дней"), (21, "21 день"),
        (22, "22 дня"), (25, "25 дней"), (111, "111 дней"),
    ])
    func russianDays(count: Int, expected: String) throws {
        #expect(try plural("plural.days", count, language: "ru") == expected)
        // Тесты идут на русском — функция L10n даёт то же.
        #expect(L10n.Plural.days(count) == expected)
    }

    @Test(arguments: [(1, "1 day"), (2, "2 days"), (5, "5 days")])
    func englishDays(count: Int, expected: String) throws {
        #expect(try plural("plural.days", count, language: "en") == expected)
    }

    // MARK: - Подстановка аргументов

    @Test func functionsSubstituteAllArguments() {
        let samples = [
            L10n.Format.minutes(45),
            L10n.Format.hours(2),
            L10n.Format.hoursMinutes(1, 30),
            L10n.Format.weeksShort(3),
            L10n.Habits.perDay("20", "мин"),
            L10n.Habits.timesPerWeek("3 раза"),
            L10n.Habits.reminderBody("Чтение"),
            L10n.Schedule.recurringQuestion("Пробежка", "каждый день"),
            L10n.Schedule.backToBack("Созвон"),
            L10n.Schedule.shortBreak(5),
            L10n.Plural.tasks(3),
            L10n.Plural.times(2),
        ]
        for text in samples {
            #expect(!text.contains("%"), "Не подставлен аргумент: \(text)")
        }
        #expect(L10n.Format.hoursMinutes(1, 30) == "1 ч 30 мин")
        #expect(L10n.Schedule.recurringQuestion("A", "B") == "«A» повторяется (B). К чему применить изменение?")
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
