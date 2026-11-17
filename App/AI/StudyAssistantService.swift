import AgentNotesCore
import Foundation
import PencilKit
import UIKit

extension SettingsKey {
    static let aiModel = "aiModel"
    static let aiLanguage = "aiLanguage"
    static let aiDailyLimit = "aiDailyLimit"
    static let aiUsage = "aiUsage"
}

/// Sends study requests to Claude with the owner's key and keeps the daily count.
@MainActor
enum StudyAssistantService {
    static let defaultDailyLimit = 20

    enum Problem: LocalizedError {
        case noKey
        case limitReached(Int)
        case nothingToRead
        case network(String)
        case api(StudyAssistant.Failure)

        var errorDescription: String? {
            switch self {
            case .noKey:
                return String(localized: "Add your Claude API key in Settings ▸ AI Assistant first.")
            case .limitReached(let limit):
                return String(localized: "You have used today's \(limit) AI requests. Change the daily limit in Settings ▸ AI Assistant.")
            case .nothingToRead:
                return String(localized: "These pages are empty. Write or import something first.")
            case .network(let detail):
                return String(localized: "No connection to the AI service. Check the internet and try again.") + "\n" + detail
            case .api(let failure):
                switch failure {
                case .invalidKey:
                    return String(localized: "The API key was not accepted. Check it in Settings ▸ AI Assistant.")
                case .rateLimited:
                    return String(localized: "Too many requests, or your account's spending limit was reached. Wait a minute, or check your limits at console.anthropic.com.")
                case .unavailable:
                    return String(localized: "The AI service is busy right now. Try again in a minute.")
                case .rejected(let message):
                    return String(localized: "The request was rejected (it may be too large: try one page).") + (message.isEmpty ? "" : "\n" + message)
                case .refused:
                    return String(localized: "The AI declined this request.")
                case .unreadable:
                    return String(localized: "The answer could not be read. Try again.")
                }
            }
        }
    }

    static var model: AIModel {
        AIModel(rawValue: UserDefaults.standard.string(forKey: SettingsKey.aiModel) ?? "") ?? .opus
    }

    static var language: AILanguage {
        if let raw = UserDefaults.standard.string(forKey: SettingsKey.aiLanguage), let value = AILanguage(rawValue: raw) {
            return value
        }
        return Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true ? .arabic : .english
    }

    static var dailyLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: SettingsKey.aiDailyLimit)
        return stored > 0 ? stored : defaultDailyLimit
    }

    static var usage: AIDailyUsage {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.aiUsage),
              let usage = try? JSONDecoder().decode(AIDailyUsage.self, from: data) else { return AIDailyUsage() }
        return usage
    }

    static var remainingToday: Int { usage.remaining(limit: dailyLimit, on: Date()) }

    private static func recordUse() {
        var current = usage
        current.record(on: Date())
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: SettingsKey.aiUsage)
        }
    }

    /// UI tests (Debug builds only) get canned answers without a key or network.
    static var isMock: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTestAIMock")
        #else
        return false
        #endif
    }

    static var isReady: Bool { isMock || AIKeyStore.hasKey }

    static func run(_ task: AITask, pages: [AIPage], language: AILanguage) async throws -> StudyAssistant.Reply {
        guard !pages.isEmpty, pages.contains(where: { $0.jpeg != nil || !$0.text.isEmpty }) else {
            throw Problem.nothingToRead
        }
        let limit = dailyLimit
        guard usage.remaining(limit: limit, on: Date()) > 0 else { throw Problem.limitReached(limit) }

        if isMock {
            try await Task.sleep(nanoseconds: 600_000_000)
            recordUse()
            return StudyAssistant.Reply(text: mockAnswer(task, language: language), isTruncated: false, inputTokens: 0, outputTokens: 0)
        }

        guard let key = AIKeyStore.load(), !key.isEmpty else { throw Problem.noKey }
        let chosenModel = Self.model
        var request = URLRequest(url: StudyAssistant.endpoint, timeoutInterval: 300)
        request.httpMethod = "POST"
        for (name, value) in StudyAssistant.headers(apiKey: key, model: chosenModel) {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try StudyAssistant.body(task: task, pages: pages, language: language, model: chosenModel)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Problem.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            let reply = try StudyAssistant.parse(data: data, statusCode: status)
            recordUse()
            return reply
        } catch let failure as StudyAssistant.Failure {
            throw Problem.api(failure)
        }
    }

    private static func mockAnswer(_ task: AITask, language: AILanguage) -> String {
        let arabic = language == .arabic
        switch task {
        case .summarize:
            return arabic
                ? "ملخص تجريبي للصفحة.\n• النقطة الأولى\n• النقطة الثانية"
                : "Test summary of the page.\n• First point\n• Second point"
        case .studySet:
            return """
            {"cards":[{"front":"Systole","back":"Contraction of the ventricles"},{"front":"Diastole","back":"Relaxation and filling"}],
             "quiz":[{"question":"Which valve separates the left atrium and left ventricle?","choices":["Tricuspid","Mitral","Aortic","Pulmonary"],"answer":1,"explanation":"The mitral (bicuspid) valve lies between the left atrium and ventricle."}]}
            """
        case .explain(let selection):
            return (arabic ? "شرح تجريبي: " : "Test explanation: ") + String(selection.prefix(40))
        case .ask(let question, _):
            return (arabic ? "إجابة تجريبية عن: " : "Test answer to: ") + question
        }
    }
}

extension EditorModel {
    enum AssistantScope: Hashable {
        case currentPage
        case notebook
        case page(UUID)
    }

    /// The pages to send: a picture of each (so handwriting can be read) plus any text on it.
    /// For the whole notebook, at most `StudyAssistant.maxPages` pages from the current one on.
    func assistantPages(scope: AssistantScope) -> [AIPage] {
        persistNow()
        let indices: [Int]
        switch scope {
        case .currentPage:
            indices = manifest.pages.indices.contains(currentPageIndex) ? [currentPageIndex] : []
        case .page(let pageID):
            indices = manifest.index(of: pageID).map { [$0] } ?? []
        case .notebook:
            let count = manifest.pages.count
            let start = count > StudyAssistant.maxPages ? min(currentPageIndex, count - StudyAssistant.maxPages) : 0
            indices = Array(start..<min(start + StudyAssistant.maxPages, count))
        }
        return indices.map { index in
            let page = manifest.pages[index]
            let pdf = pdfPage(for: page)
            let layer = objects(for: page.id)
            var texts: [String] = []
            if let pdfText = pdf?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !pdfText.isEmpty {
                texts.append(pdfText)
            }
            texts += layer.objects.filter(\.hasText).compactMap(\.text).filter { !$0.isEmpty }
            var ink: PKDrawing?
            if case .drawing(let drawing) = loadInk(for: page.id) { ink = drawing }
            var pictures: [String: UIImage] = [:]
            for name in layer.objects.compactMap(\.assetFileName) {
                pictures[name] = asset(named: name)
            }
            let image = PageRenderer.image(
                page: page,
                pdfPage: pdf,
                backgroundImage: page.backgroundAsset.flatMap { asset(named: $0) },
                objects: layer,
                asset: { pictures[$0] },
                ink: ink,
                maxDimension: 784)
            return AIPage(number: index + 1, text: texts.joined(separator: "\n"), jpeg: image.jpegData(compressionQuality: 0.7))
        }
    }
}
