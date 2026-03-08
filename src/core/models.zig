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
    has_tower: bool,
};

pub const Runway = struct {
    airport_icao: []const u8,
    width: f32,
    lat: f64,
    lon: f64,
    number: []const u8,
};

pub const AirportRecord = union(enum) {
    airport: Airport,
    runways: []const Runway,
};
