import 'dart:convert';

import 'package:arcane_chat/constant.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class ArcaneConnect {
  static Web3Client _client;

  static Web3Client connect() {
    if (_client == null) {
      _client = new Web3Client(Constant.INFURA_API, Client());
    }

    return _client;
  }

  static Future<double> getUSDPrice() async => Client()
          .get(
              "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD&api_key=${Constant.CRYPTO_COMPARE_API_KEY}")
          .then((value) {
        print("Got result ${value.body}");
        return double.tryParse(
                (jsonDecode(value.body) as Map<String, dynamic>)["USD"]
                    .toString()) ??
            2;
      });
}