import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';

class ConnectionProvider extends ChangeNotifier {
  bool _hasInternet = false;
  bool get hasInternet => _hasInternet;

  ConnectionProvider() {
    checkHasInternet();
  }
  Future<void> checkHasInternet() async {
    var internetStatus = await Connectivity().checkConnectivity();
    if (internetStatus == ConnectivityResult.none) {
      _hasInternet = false;
    } else {
      _hasInternet = true;
    }
    notifyListeners();
  }
}
