class MapConfig {
  static const String mapStyle = '''
[
  {
    "featureType": "all",
    "elementType": "all",
    "stylers": [

      {
        "saturation": 20
      },
      {
        "lightness": 20
      },
      {
        "gamma": 0.9
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 0
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 5
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 10
      }
    ]
  }
]
''';
  static const String mapStyleDark = '''
[
  {
    "featureType": "all",
    "elementType": "all",
    "stylers": [
      {
        "invert_lightness": true
      },
      {
        "saturation": 1
      },
      {
        "lightness": 20
      },
      {
        "gamma": 0.9
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 0
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 5
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry",
    "stylers": [
      {
        "hue": "#5949eb"
      },
      {
        "saturation": 40
      },
      {
        "lightness": 10
      }
    ]
  }
]
''';
}
