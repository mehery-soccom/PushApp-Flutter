part of mehery_sender;

/// Location/session payload you supply for [Pushapp.postSessionGeo].
///
/// Serialized as the **`geoIP`** object in `POST /pushapp/api/session/geo`.
class PushSessionGeoData {
  /// IPv4 address for this device/session (as your app or backend determines).
  final String ip;

  /// Latitude in decimal degrees (WGS‑84).
  final double lat;

  /// Longitude in decimal degrees (WGS‑84).
  final double lng;

  /// Country ISO code (e.g. `IN`, `US`).
  final String countryIsoCode;

  /// Country display name.
  final String countryName;

  /// Region/state ISO code (e.g. `MH`, `NY`).
  final String regionIsoCode;

  /// Region/state display name.
  final String regionName;

  /// City name.
  final String cityName;

  /// Area/neighborhood name (or locality).
  final String areaName;

  const PushSessionGeoData({
    required this.ip,
    required this.lat,
    required this.lng,
    required this.countryIsoCode,
    required this.countryName,
    required this.regionIsoCode,
    required this.regionName,
    required this.cityName,
    required this.areaName,
  });

  Map<String, dynamic> toGeoIpJson() => {
        'ip': ip,
        'location': {
          'lat': lat,
          'lng': lng,
        },
        'country': {
          'iso_code': countryIsoCode,
          'name': countryName,
        },
        'region': {
          'iso_code': regionIsoCode,
          'name': regionName,
        },
        'city': {'name': cityName},
        'area': {'name': areaName},
      };
}
