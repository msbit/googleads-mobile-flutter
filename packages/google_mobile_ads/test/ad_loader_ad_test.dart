// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/src/ad_containers.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ad_listeners.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad Loader Ad Tests', () {
    final List<MethodCall> log = <MethodCall>[];

    setUp(() async {
      log.clear();
      instanceManager =
          AdInstanceManager('plugins.flutter.io/google_mobile_ads');
      instanceManager.channel
          .setMockMethodCallHandler((MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getAdLoaderAdType':
            return Future<dynamic>.value(0);
          case 'getAdSize':
            return Future<dynamic>.value(AdSize.banner);
          case 'getFormatId':
            return Future<dynamic>.value('format-id');
          case 'loadAdLoaderAd':
            return Future<void>.value();
          default:
            assert(false);
            return null;
        }
      });
    });

    test('load with $AdRequest', () async {
      final AdRequest request = AdRequest();
      final AdLoaderAd adLoaderAd = AdLoaderAd(
        adUnitId: 'test-ad-unit',
        listener: AdLoaderAdListener(),
        request: request,
      );

      await adLoaderAd.load();

      expect(log, <Matcher>[
        isMethodCall('loadAdLoaderAd', arguments: <String, dynamic>{
          'adId': 0,
          'adUnitId': 'test-ad-unit',
          'request': request,
          'adManagerRequest': null,
        })
      ]);

      expect(instanceManager.adFor(0), isNotNull);
    });

    test('load with $AdManagerAdRequest', () async {
      final AdManagerAdRequest request = AdManagerAdRequest();
      final AdLoaderAd adLoaderAd = AdLoaderAd(
        adUnitId: 'test-ad-unit',
        listener: AdLoaderAdListener(),
        request: request,
      );

      await adLoaderAd.load();

      expect(log, <Matcher>[
        isMethodCall('loadAdLoaderAd', arguments: <String, dynamic>{
          'adId': 0,
          'adUnitId': 'test-ad-unit',
          'request': null,
          'adManagerRequest': request,
        })
      ]);

      expect(instanceManager.adFor(0), isNotNull);
    });

    test('getAdLoaderAdType delegates to $MethodChannel', () async {
      final AdLoaderAd adLoaderAd = AdLoaderAd(
        adUnitId: 'test-ad-unit',
        listener: AdLoaderAdListener(),
        request: AdRequest(),
      );

      final result = await adLoaderAd.getAdLoaderAdType();

      expect(result, equals(AdLoaderAdType.unknown));

      expect(log, <Matcher>[
        isMethodCall('getAdLoaderAdType', arguments: <String, dynamic>{
          'adId': null,
        })
      ]);
    });

    test('getFormatId delegates to $MethodChannel', () async {
      final AdLoaderAd adLoaderAd = AdLoaderAd(
        adUnitId: 'test-ad-unit',
        listener: AdLoaderAdListener(),
        request: AdRequest(),
      );

      final result = await adLoaderAd.getFormatId();

      expect(result, equals('format-id'));

      expect(log, <Matcher>[
        isMethodCall('getFormatId', arguments: <String, dynamic>{
          'adId': null,
        })
      ]);
    });

    test('getPlatformAdSize delegates to $MethodChannel', () async {
      final AdLoaderAd adLoaderAd = AdLoaderAd(
        adUnitId: 'test-ad-unit',
        listener: AdLoaderAdListener(),
        request: AdRequest(),
      );

      final result = await adLoaderAd.getPlatformAdSize();

      expect(result, equals(AdSize.banner));

      expect(log, <Matcher>[
        isMethodCall('getAdSize', arguments: <String, dynamic>{
          'adId': null,
        })
      ]);
    });

    test('onAdLoaded event', () async {
      var testOnAdLoaded = (eventName, adId) async {
        final Completer<Ad> completer = Completer<Ad>();

        final AdLoaderAd ad = AdLoaderAd(
          adUnitId: 'test-ad-unit',
          listener:
              AdLoaderAdListener(onAdLoaded: (ad) => completer.complete(ad)),
          request: AdRequest(),
        );

        await ad.load();

        final MethodCall methodCall = MethodCall('onAdEvent',
            <dynamic, dynamic>{'adId': adId, 'eventName': eventName});

        final ByteData data =
            instanceManager.channel.codec.encodeMethodCall(methodCall);

        await instanceManager.channel.binaryMessenger.handlePlatformMessage(
          'plugins.flutter.io/google_mobile_ads',
          data,
          (ByteData? data) {},
        );

        expect(completer.future, completion(ad));
      };

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await testOnAdLoaded('onAdLoaded', 0);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await testOnAdLoaded('onAdLoaded', 1);
    });

    test('onAdFailedToLoad event', () async {
      var testOnAdFailedToLoad = (eventName, adId) async {
        final Completer<Ad> completer = Completer<Ad>();

        final AdLoaderAd ad = AdLoaderAd(
          adUnitId: 'test-ad-unit',
          listener: AdLoaderAdListener(
              onAdFailedToLoad: (ad, error) => completer.complete(ad)),
          request: AdRequest(),
        );

        await ad.load();

        final MethodCall methodCall =
            MethodCall('onAdEvent', <dynamic, dynamic>{
          'adId': adId,
          'eventName': eventName,
          'loadAdError': LoadAdError(0, '', '', null)
        });

        final ByteData data =
            instanceManager.channel.codec.encodeMethodCall(methodCall);

        await instanceManager.channel.binaryMessenger.handlePlatformMessage(
          'plugins.flutter.io/google_mobile_ads',
          data,
          (ByteData? data) {},
        );

        expect(completer.future, completion(ad));
      };

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await testOnAdFailedToLoad('onAdFailedToLoad', 0);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await testOnAdFailedToLoad('onAdFailedToLoad', 1);
    });

    test('onAdClicked event', () async {
      var testOnAdClicked = (eventName, adId) async {
        final Completer<Ad> completer = Completer<Ad>();

        final AdLoaderAd ad = AdLoaderAd(
          adUnitId: 'test-ad-unit',
          listener:
              AdLoaderAdListener(onAdClicked: (ad) => completer.complete(ad)),
          request: AdRequest(),
        );

        await ad.load();

        final MethodCall methodCall = MethodCall('onAdEvent',
            <dynamic, dynamic>{'adId': adId, 'eventName': eventName});

        final ByteData data =
            instanceManager.channel.codec.encodeMethodCall(methodCall);

        await instanceManager.channel.binaryMessenger.handlePlatformMessage(
          'plugins.flutter.io/google_mobile_ads',
          data,
          (ByteData? data) {},
        );

        expect(completer.future, completion(ad));
      };

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await testOnAdClicked('adDidRecordClick', 0);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await testOnAdClicked('onAdClicked', 1);
    });
  });
}
