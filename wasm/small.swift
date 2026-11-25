import Foundation

public struct Coordinate: Codable, Equatable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }

  public func distance(to other: Coordinate) -> Double {
    let dLat = (other.latitude - latitude) * .pi / 180.0
    let dLon = (other.longitude - longitude) * .pi / 180.0
    let a = sin(dLat / 2) * sin(dLat / 2)
      + cos(latitude * .pi / 180.0) * cos(other.latitude * .pi / 180.0)
      * sin(dLon / 2) * sin(dLon / 2)
    return 6_371_000.0 * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
  }
}

public final class RoutePlanner {
  private var waypoints: [Coordinate] = []
  private var cache: [String: [[Coordinate]]] = [:]

  public init(waypoints: [Coordinate] = []) {
    self.waypoints = waypoints
  }

  public func add(_ waypoint: Coordinate) {
    waypoints.append(waypoint)
    cache.removeAll()
  }

  public func route(named name: String) -> [Coordinate] {
    if let cached = cache[name] {
      return cached.flatMap { $0 }
    }
    let sorted = waypoints.sorted { a, b in
      a.latitude < b.latitude || (a.latitude == b.latitude && a.longitude < b.longitude)
    }
    cache[name] = [sorted]
    return sorted
  }

  public var totalDistance: Double {
    guard waypoints.count > 1 else { return 0 }
    var total = 0.0
    for i in 1..<waypoints.count {
      total += waypoints[i - 1].distance(to: waypoints[i])
    }
    return total
  }
}
