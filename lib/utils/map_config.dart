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
        "lightness": 10
      },
      {
        "gamma": 0.5
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
        "color": "#cfcbf7"
      },
      {
        "saturation": 80
      },
      {
        "lightness": 0
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
        "saturation": 20
      },
      {
        "lightness": 2
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#a0d468" }
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
        "saturation": 10
      },
      {
        "lightness": 55
      },
      {
        "gamma": .5
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
        "saturation": 10
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
        "saturation": 20
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
        "saturation": 2
      },
      {
        "lightness": 5
      }
    ]
  },
   {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      { "color": "#a0d468" }
    ]
  }
]
''';
}
