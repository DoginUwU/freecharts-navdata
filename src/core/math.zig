const std = @import("std");

pub fn haversineDistance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) f64 {
    const r = 3440.065; // Earth radius in nautical miles
    const d_lat = (lat2 - lat1) * (std.math.pi / 180.0);
    const d_lon = (lon2 - lon1) * (std.math.pi / 180.0);

    const a = std.math.pow(f64, std.math.sin(d_lat / 2.0), 2) +
        std.math.cos(lat1 * (std.math.pi / 180.0)) * std.math.cos(lat2 * (std.math.pi / 180.0)) *
            std.math.pow(f64, std.math.sin(d_lon / 2.0), 2);

    const c = 2.0 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1.0 - a));
    return r * c;
}
