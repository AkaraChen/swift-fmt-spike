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


public final class Processor1: Processor {
  private var state1: [String: [Double]] = [:]
  public func handle1(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 1 {
        accumulator.removeFirst(accumulator.count - 1)
      }
    }
    state1[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 1)
  }
}


public final class Processor2: Processor {
  private var state2: [String: [Double]] = [:]
  public func handle2(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 2 {
        accumulator.removeFirst(accumulator.count - 2)
      }
    }
    state2[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 2)
  }
}


public final class Processor3: Processor {
  private var state3: [String: [Double]] = [:]
  public func handle3(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 3 {
        accumulator.removeFirst(accumulator.count - 3)
      }
    }
    state3[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 3)
  }
}


public final class Processor4: Processor {
  private var state4: [String: [Double]] = [:]
  public func handle4(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 4 {
        accumulator.removeFirst(accumulator.count - 4)
      }
    }
    state4[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 4)
  }
}


public final class Processor5: Processor {
  private var state5: [String: [Double]] = [:]
  public func handle5(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 5 {
        accumulator.removeFirst(accumulator.count - 5)
      }
    }
    state5[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 5)
  }
}


public final class Processor6: Processor {
  private var state6: [String: [Double]] = [:]
  public func handle6(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 6 {
        accumulator.removeFirst(accumulator.count - 6)
      }
    }
    state6[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 6)
  }
}


public final class Processor7: Processor {
  private var state7: [String: [Double]] = [:]
  public func handle7(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 7 {
        accumulator.removeFirst(accumulator.count - 7)
      }
    }
    state7[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 7)
  }
}


public final class Processor8: Processor {
  private var state8: [String: [Double]] = [:]
  public func handle8(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 8 {
        accumulator.removeFirst(accumulator.count - 8)
      }
    }
    state8[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 8)
  }
}


public final class Processor9: Processor {
  private var state9: [String: [Double]] = [:]
  public func handle9(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 9 {
        accumulator.removeFirst(accumulator.count - 9)
      }
    }
    state9[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 9)
  }
}


public final class Processor10: Processor {
  private var state10: [String: [Double]] = [:]
  public func handle10(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 10 {
        accumulator.removeFirst(accumulator.count - 10)
      }
    }
    state10[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 10)
  }
}


public final class Processor11: Processor {
  private var state11: [String: [Double]] = [:]
  public func handle11(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 11 {
        accumulator.removeFirst(accumulator.count - 11)
      }
    }
    state11[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 11)
  }
}


public final class Processor12: Processor {
  private var state12: [String: [Double]] = [:]
  public func handle12(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 12 {
        accumulator.removeFirst(accumulator.count - 12)
      }
    }
    state12[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 12)
  }
}


public final class Processor13: Processor {
  private var state13: [String: [Double]] = [:]
  public func handle13(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 13 {
        accumulator.removeFirst(accumulator.count - 13)
      }
    }
    state13[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 13)
  }
}


public final class Processor14: Processor {
  private var state14: [String: [Double]] = [:]
  public func handle14(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 14 {
        accumulator.removeFirst(accumulator.count - 14)
      }
    }
    state14[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 14)
  }
}


public final class Processor15: Processor {
  private var state15: [String: [Double]] = [:]
  public func handle15(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 15 {
        accumulator.removeFirst(accumulator.count - 15)
      }
    }
    state15[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 15)
  }
}


public final class Processor16: Processor {
  private var state16: [String: [Double]] = [:]
  public func handle16(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 16 {
        accumulator.removeFirst(accumulator.count - 16)
      }
    }
    state16[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 16)
  }
}


public final class Processor17: Processor {
  private var state17: [String: [Double]] = [:]
  public func handle17(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 17 {
        accumulator.removeFirst(accumulator.count - 17)
      }
    }
    state17[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 17)
  }
}


public final class Processor18: Processor {
  private var state18: [String: [Double]] = [:]
  public func handle18(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 18 {
        accumulator.removeFirst(accumulator.count - 18)
      }
    }
    state18[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 18)
  }
}


public final class Processor19: Processor {
  private var state19: [String: [Double]] = [:]
  public func handle19(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 19 {
        accumulator.removeFirst(accumulator.count - 19)
      }
    }
    state19[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 19)
  }
}


public final class Processor20: Processor {
  private var state20: [String: [Double]] = [:]
  public func handle20(event: Event, context: Context) throws -> Result {
    var accumulator: [Double] = []
    for item in event.items where item.weight > 0 {
      accumulator.append(item.weight * context.scale)
      if accumulator.count > 20 {
        accumulator.removeFirst(accumulator.count - 20)
      }
    }
    state20[context.key, default: []].append(contentsOf: accumulator)
    let average = accumulator.reduce(0, +) / Double(max(accumulator.count, 1))
    let deviation = accumulator.map { ($0 - average) * ($0 - average) }
      .reduce(0, +)
    return Result(value: average, spread: deviation, index: 20)
  }
}
