import Foundation

enum WidgetAppGroup: Sendable {
    nonisolated static let id = "group.digitalunknown.Trip-Planner"
    nonisolated static let snapshotFile = "widget-trip-snapshot.plist"
    nonisolated static let coverFile = "widget-trip-cover.jpg"
    nonisolated static let statusFile = "widget-status.txt"
}

struct WidgetSnapshotRead {
    var envelope: WidgetSnapshotEnvelope?
    var diagnostics: String
}

enum WidgetSnapshotStore {
    nonisolated static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.id)
    }
    
    nonisolated static func writeStatus(_ message: String) {
        guard let url = containerURL?.appendingPathComponent(WidgetAppGroup.statusFile) else {
            print("Widget status skipped, no App Group container")
            return
        }
        writeFile(Data(message.utf8), to: url)
    }
    
    nonisolated static func write(_ envelope: WidgetSnapshotEnvelope, coverJPEG: Data?) {
        let status: String
        if let trip = envelope.trip {
            status = "ok · \(trip.tripName)"
        } else {
            status = "no trip selected"
        }
        
        if envelope.trip == nil, read().envelope?.trip != nil {
            writeStatus(status + " · kept last trip")
            return
        }
        
        guard let container = containerURL else {
            print("Widget snapshot write failed: no App Group container")
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        } catch {
            print("Widget snapshot directory failed:", error)
        }
        
        let plist = plist(from: envelope)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            writeStatus("plist encode failed · \(status)")
            return
        }
        
        writeFile(data, to: container.appendingPathComponent(WidgetAppGroup.snapshotFile))
        writeStatus(status)
        
        let coverURL = container.appendingPathComponent(WidgetAppGroup.coverFile)
        if let coverJPEG, !coverJPEG.isEmpty {
            writeFile(coverJPEG, to: coverURL)
        } else {
            try? FileManager.default.removeItem(at: coverURL)
        }
        
        if let trip = envelope.trip {
            for item in trip.items {
                let url = container.appendingPathComponent("widget-icon-\(item.id.uuidString).png")
                if let png = item.iconPNG, !png.isEmpty {
                    writeFile(png, to: url)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        
    }
    
    nonisolated static func read() -> WidgetSnapshotRead {
        guard let container = containerURL else {
            return WidgetSnapshotRead(envelope: nil, diagnostics: "App Group unavailable")
        }
        
        let status = (try? String(
            contentsOf: container.appendingPathComponent(WidgetAppGroup.statusFile),
            encoding: .utf8
        ))?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let files = [
            WidgetAppGroup.snapshotFile,
            "widget-trip-snapshot.json"
        ]
        for name in files {
            let url = container.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            if var envelope = envelope(fromPlistData: data) ?? decodeJSON(data) {
                if var trip = envelope.trip {
                    trip.items = trip.items.map { item in
                        var copy = item
                        if copy.iconPNG == nil {
                            copy.iconPNG = try? Data(
                                contentsOf: container.appendingPathComponent("widget-icon-\(item.id.uuidString).png")
                            )
                        }
                        return copy
                    }
                    envelope.trip = trip
                }
                return WidgetSnapshotRead(
                    envelope: envelope,
                    diagnostics: status ?? (envelope.trip == nil ? "snapshot empty" : "ok")
                )
            }
        }
        
        return WidgetSnapshotRead(envelope: nil, diagnostics: status ?? "No snapshot yet")
    }
    
    nonisolated static func readCoverJPEG() -> Data? {
        guard let container = containerURL else { return nil }
        return try? Data(contentsOf: container.appendingPathComponent(WidgetAppGroup.coverFile))
    }
    
    nonisolated private static func writeFile(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: [.atomic, .noFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: url.path
            )
        } catch {
            print("Widget file write failed:", url.lastPathComponent, error)
        }
    }
    
    nonisolated private static func plist(from envelope: WidgetSnapshotEnvelope) -> [String: Any] {
        var root: [String: Any] = [
            "lastUpdated": envelope.lastUpdated.timeIntervalSince1970
        ]
        guard let trip = envelope.trip else { return root }
        
        var items: [[String: Any]] = []
        for item in trip.items {
            var row: [String: Any] = [
                "id": item.id.uuidString,
                "kind": item.kind.rawValue,
                "title": item.title
            ]
            if let startTime = item.startTime { row["startTime"] = startTime }
            if let startMinutes = item.startMinutes { row["startMinutes"] = startMinutes }
            if let icon = item.icon { row["icon"] = icon }
            if let accentHex = item.accentHex { row["accentHex"] = Int(accentHex) }
            if let accentForegroundHex = item.accentForegroundHex {
                row["accentForegroundHex"] = Int(accentForegroundHex)
            }
            items.append(row)
        }
        
        let followingDays = trip.followingDays ?? []
        var tripDict: [String: Any] = [
            "tripID": trip.tripID.uuidString,
            "tripName": trip.tripName,
            "destination": trip.destination,
            "tintHex": Int(trip.tintHex),
            "dateMode": trip.dateMode.rawValue,
            "selection": trip.selection.rawValue,
            "statusLine": trip.statusLine,
            "dayLabel": trip.dayLabel,
            "items": items,
            "ideaCount": trip.ideaCount,
            "lastUpdated": trip.lastUpdated.timeIntervalSince1970,
            "dayNumber": trip.dayNumber ?? 1
        ]
        if let coverFileName = trip.coverFileName { tripDict["coverFileName"] = coverFileName }
        if let dayID = trip.dayID { tripDict["dayID"] = dayID.uuidString }
        if let dayDate = trip.dayDate { tripDict["dayDate"] = dayDate.timeIntervalSince1970 }
        if let dateSpanText = trip.dateSpanText { tripDict["dateSpanText"] = dateSpanText }
        if !followingDays.isEmpty {
            tripDict["followingDays"] = followingDays.map { peek in
                [
                    "id": peek.id.uuidString,
                    "label": peek.label,
                    "detail": peek.detail,
                    "itemCount": peek.itemCount
                ] as [String: Any]
            }
        }
        root["trip"] = tripDict
        return root
    }
    
    nonisolated private static func envelope(fromPlistData data: Data) -> WidgetSnapshotEnvelope? {
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let root = object as? [String: Any] else { return nil }
        return envelope(fromPlist: root)
    }
    
    nonisolated private static func envelope(fromPlist root: [String: Any]) -> WidgetSnapshotEnvelope? {
        let lastUpdated = date(root["lastUpdated"]) ?? Date()
        guard let tripDict = root["trip"] as? [String: Any] else {
            return WidgetSnapshotEnvelope(trip: nil, lastUpdated: lastUpdated)
        }
        guard let tripID = uuid(tripDict["tripID"]),
              let tripName = tripDict["tripName"] as? String else { return nil }
        
        let itemRows = tripDict["items"] as? [[String: Any]] ?? []
        let items: [WidgetTripItem] = itemRows.compactMap { row in
            guard let id = uuid(row["id"]),
                  let kindRaw = row["kind"] as? String,
                  let kind = WidgetItemKind(rawValue: kindRaw),
                  let title = row["title"] as? String else { return nil }
            return WidgetTripItem(
                id: id,
                kind: kind,
                title: title,
                startTime: row["startTime"] as? String,
                startMinutes: intValue(row["startMinutes"]),
                icon: row["icon"] as? String,
                accentHex: uint32(row["accentHex"]),
                accentForegroundHex: uint32(row["accentForegroundHex"])
            )
        }
        
        let following = (tripDict["followingDays"] as? [[String: Any]] ?? []).compactMap { row -> WidgetDayPeek? in
            guard let id = uuid(row["id"]),
                  let label = row["label"] as? String,
                  let detail = row["detail"] as? String else { return nil }
            return WidgetDayPeek(
                id: id,
                label: label,
                detail: detail,
                itemCount: intValue(row["itemCount"]) ?? 0
            )
        }
        
        let snapshot = WidgetTripSnapshot(
            tripID: tripID,
            tripName: tripName,
            destination: tripDict["destination"] as? String ?? "",
            coverFileName: tripDict["coverFileName"] as? String,
            tintHex: uint32(tripDict["tintHex"]) ?? 0xFF8B00,
            dateMode: WidgetDateMode(rawValue: tripDict["dateMode"] as? String ?? "") ?? .dated,
            selection: WidgetTripSelection(rawValue: tripDict["selection"] as? String ?? "") ?? .upcoming,
            statusLine: tripDict["statusLine"] as? String ?? "",
            dayID: uuid(tripDict["dayID"]),
            dayLabel: tripDict["dayLabel"] as? String ?? "",
            dayDate: date(tripDict["dayDate"]),
            items: items,
            ideaCount: intValue(tripDict["ideaCount"]) ?? 0,
            lastUpdated: date(tripDict["lastUpdated"]) ?? lastUpdated,
            dayNumber: intValue(tripDict["dayNumber"]),
            dateSpanText: tripDict["dateSpanText"] as? String,
            followingDays: following
        )
        return WidgetSnapshotEnvelope(trip: snapshot, lastUpdated: lastUpdated)
    }
    
    nonisolated private static func decodeJSON(_ data: Data) -> WidgetSnapshotEnvelope? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WidgetSnapshotEnvelope.self, from: data)
    }
    
    nonisolated private static func uuid(_ value: Any?) -> UUID? {
        (value as? String).flatMap(UUID.init(uuidString:))
    }
    
    nonisolated private static func date(_ value: Any?) -> Date? {
        if let interval = value as? TimeInterval { return Date(timeIntervalSince1970: interval) }
        if let interval = value as? Int { return Date(timeIntervalSince1970: TimeInterval(interval)) }
        if let interval = value as? Double { return Date(timeIntervalSince1970: interval) }
        return nil
    }
    
    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Int64 { return Int(number) }
        if let number = value as? Double { return Int(number) }
        return nil
    }
    
    nonisolated private static func uint32(_ value: Any?) -> UInt32? {
        if let number = value as? Int { return UInt32(number) }
        if let number = value as? UInt32 { return number }
        if let number = value as? Int64 { return UInt32(truncatingIfNeeded: number) }
        if let number = value as? Double { return UInt32(number) }
        return nil
    }
}
