import Foundation

/// In-app diagnostic log. Kept small (latest 300 entries) and
/// exportable as plain text from DiagnosticsView.
final class AppLogStore: ObservableObject {
    @Published private(set) var entries: [String] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    func log(_ message: String) {
        let line = "\(dateFormatter.string(from: Date())) \(message)"
        DispatchQueue.main.async {
            self.entries.append(line)
            if self.entries.count > 300 {
                self.entries.removeFirst(self.entries.count - 300)
            }
        }
    }

    func clear() {
        entries.removeAll()
    }

    var exportText: String {
        entries.joined(separator: "\n")
    }
}
