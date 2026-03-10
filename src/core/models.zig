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

pub const DirectionRestriction = enum {
    NONE,
    FORWARD,
    BACKWARD,
};

pub const AirwayLevel = enum {
    HIGH,
    LOW,
};

pub const AirwayFixNavaidType = enum {
    FIX,
    VOR,
    NDB,
};

pub const Airway = struct {
    from_ident: []const u8,
    from_lat: f64,
    from_lon: f64,
    from_type: AirwayFixNavaidType,
    from_region: []const u8,
    to_ident: []const u8,
    to_lat: f64,
    to_lon: f64,
    to_type: AirwayFixNavaidType,
    to_region: []const u8,
    airway_name: []const u8,
    direction_restriction: DirectionRestriction,
    level: AirwayLevel,
    base_altitude: i32,
    top_altitude: i32,
    distance_nm: f64,
};

pub const ProcedureType = enum {
    SID,
    STAR,
    APPCH,
};

pub const ProcedureLeg = struct {
    icao: []const u8,
    proc_name: []const u8,
    fix_ident: []const u8,
    leg_type: []const u8,
    transition_ident: []const u8,
    type: ProcedureType,
    sequence: u32,
};

pub const NavaidType = enum {
    VOR,
    NDB,
};

pub const Navaid = struct {
    ident: []const u8,
    type: NavaidType,
    lat: f64,
    lon: f64,
    frequency: i32,
    region: []const u8,
    name: []const u8,
};
