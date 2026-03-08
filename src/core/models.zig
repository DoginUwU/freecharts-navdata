pub const Fix = struct {
    lat: f64,
    lon: f64,
    ident: []const u8,
    airport: []const u8,
    region: []const u8,
};

pub const Airport = struct {
    icao: []const u8,
    name: []const u8,
    elevation: i32,
    lat: f64,
    lon: f64,
};

pub const Runway = struct {
    airport_icao: []const u8,
    width: f32,
    lat: f64,
    lon: f64,
    number: []const u8,
};

pub const Gate = struct {
    airport_icao: []const u8,
    name: []const u8,
    lat: f64,
    lon: f64,
};

pub const AirportRecord = union(enum) {
    airport: Airport,
    runways: []const Runway,
    gates: []const Gate,

    // XP Only
    xp_airport_metadata: XPAirportMetadata,
};

// XP Only
pub const XPAirportMetadata = struct {
    icao: []const u8,
    lon: f64,
    lat: f64,
};
