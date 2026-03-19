import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadowprice_ai/services/shadowprice_api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('falls back to local URL analysis when backend analyze fails', () async {
    const productUrl = 'https://example.com/products/widget-pro-2';
    final client = MockClient((request) async {
      if (request.url.toString() == 'http://10.0.2.2:8000/api/v1/analyze') {
        return http.Response(
          jsonEncode({'detail': 'backend offline'}),
          503,
          headers: const {'content-type': 'application/json'},
        );
      }

      if (request.url.toString() == productUrl) {
        return http.Response(
          '''
          <html>
            <head>
              <title>Widget Pro 2 | Example Store</title>
              <meta property="og:type" content="product" />
              <meta property="og:title" content="Widget Pro 2" />
              <meta property="og:site_name" content="Example Store" />
              <meta property="product:price:amount" content="499.99" />
              <meta property="product:price:currency" content="USD" />
            </head>
            <body>
              <h1>Widget Pro 2</h1>
            </body>
          </html>
          ''',
          200,
          headers: const {'content-type': 'text/html'},
        );
      }

      fail('Unexpected request: ${request.url}');
    });

    final service = ShadowPriceApiService(client: client);
    addTearDown(service.dispose);

    final analysis = await service.analyze(productUrl);

    expect(analysis.productName, 'Widget Pro 2');
    expect(analysis.offers, hasLength(1));
    expect(analysis.cheapestOffer?.marketplace, 'Example Store');
    expect(analysis.cheapestOffer?.price, 499.99);
    expect(analysis.sourceProduct?.productUrl, productUrl);
  });
}
