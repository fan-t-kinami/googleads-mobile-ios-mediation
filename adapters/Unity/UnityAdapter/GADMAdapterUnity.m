// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADMAdapterUnity.h"

#import "GADMAdapterUnityConstants.h"
#import "GADMAdapterUnitySingleton.h"
#import "GADMediationAdapterUnity.h"
#import "GADUnityError.h"

@interface GADMAdapterUnity () {
  /// Connector from Google Mobile Ads SDK to receive ad configurations.
  __weak id<GADMAdNetworkConnector> _networkConnector;

  /// Placement ID of Unity Ads network.
  NSString *_placementID;

  /// YES if the adapter is loading.
  BOOL _isLoading;
}

@end

@implementation GADMAdapterUnity

+ (nonnull Class<GADMediationAdapter>)mainAdapterClass {
  return [GADMediationAdapterUnity class];
}

+ (NSString *)adapterVersion {
  return kGADMAdapterUnityVersion;
}

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
  return Nil;
}

- (void)stopBeingDelegate {
  [[GADMAdapterUnitySingleton sharedInstance] stopTrackingDelegate:self];
}

#pragma mark Interstitial Methods

- (instancetype)initWithGADMAdNetworkConnector:(id<GADMAdNetworkConnector>)connector {
  if (!connector) {
    return nil;
  }

  self = [super init];
  if (self) {
    _networkConnector = connector;
  }
  return self;
}

- (void)getInterstitial {
  id<GADMAdNetworkConnector> strongConnector = _networkConnector;
  NSString *gameID = [[[strongConnector credentials] objectForKey:kGADMAdapterUnityGameID] copy];
  _placementID = [[[strongConnector credentials] objectForKey:kGADMAdapterUnityPlacementID] copy];
  if (!gameID || !_placementID) {
    NSError *error = GADUnityErrorWithDescription(@"Game ID and Placement ID cannot be nil.");
    [strongConnector adapter:self didFailAd:error];
    return;
  }
  _isLoading = YES;
  [[GADMAdapterUnitySingleton sharedInstance] configureInterstitialAdWithGameID:gameID
                                                                       delegate:self];
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)rootViewController {
  // We will send adapterWillPresentInterstitial callback before presenting unity ad because the ad
  // has already loaded.
  [_networkConnector adapterWillPresentInterstitial:self];
  [[GADMAdapterUnitySingleton sharedInstance]
      presentInterstitialAdForViewController:rootViewController
                                    delegate:self];
}

#pragma mark Banner Methods

- (void)getBannerWithSize:(GADAdSize)adSize {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  NSString *gameID =
      [[[strongNetworkConnector credentials] objectForKey:kGADMAdapterUnityGameID] copy];
  _placementID =
      [[[strongNetworkConnector credentials] objectForKey:kGADMAdapterUnityPlacementID] copy];
  if (!gameID || !_placementID) {
    NSError *error = GADUnityErrorWithDescription(@"Game ID and Placement ID cannot be nil.");
    [strongNetworkConnector adapter:self didFailAd:error];
    return;
  }
  [[GADMAdapterUnitySingleton sharedInstance] presentBannerAd:gameID delegate:self];
}

- (BOOL)isBannerAnimationOK:(GADMBannerAnimationType)animType {
  return YES;
}

#pragma mark GADMAdapterUnityDataProvider Methods

- (NSString *)getPlacementID {
  return _placementID;
}

#pragma mark - Unity Delegate Methods

- (void)unityAdsPlacementStateChanged:(NSString *)placementId
                             oldState:(UnityAdsPlacementState)oldState
                             newState:(UnityAdsPlacementState)newState {
  // This callback is not forwarded to the adapter by the GADMAdapterUnitySingleton and the adapter
  // should use the unityAdsReady: and unityAdsDidError: callbacks to forward Unity Ads SDK state to
  // Google Mobile Ads SDK.
}

- (void)unityAdsDidFinish:(NSString *)placementID withFinishState:(UnityAdsFinishState)state {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (strongNetworkConnector) {
    [strongNetworkConnector adapterWillDismissInterstitial:self];
    [strongNetworkConnector adapterDidDismissInterstitial:self];
  }
}

- (void)unityAdsReady:(NSString *)placementID {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (!_isLoading) {
    return;
  }

  if (strongNetworkConnector) {
    [strongNetworkConnector adapterDidReceiveInterstitial:self];
  }
  _isLoading = NO;
}

- (void)unityAdsDidClick:(NSString *)placementID {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  // The Unity Ads SDK doesn't provide an event for leaving the application, so the adapter assumes
  // that a click event indicates the user is leaving the application for a browser or deeplink, and
  // notifies the Google Mobile Ads SDK accordingly.
  if (strongNetworkConnector) {
    [strongNetworkConnector adapterDidGetAdClick:self];
    [strongNetworkConnector adapterWillLeaveApplication:self];
  }
}

- (void)unityAdsDidError:(UnityAdsError)error withMessage:(NSString *)message {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (!_isLoading) {
    // Unity Ads show error will only happen after the ad has been loaded. So, we will send
    // dismiss/close callbacks.
    if (error == kUnityAdsErrorShowError) {
      if (strongNetworkConnector) {
        [strongNetworkConnector adapterWillDismissInterstitial:self];
        [strongNetworkConnector adapterDidDismissInterstitial:self];
      }
    }
    return;
  }

  NSError *errorWithDescription = GADUnityErrorWithDescription(message);
  if (strongNetworkConnector) {
    [strongNetworkConnector adapter:self didFailAd:errorWithDescription];
  }
  _isLoading = NO;
}

- (void)unityAdsDidStart:(nonnull NSString *)placementId {
  // nothing to do
}

#pragma mark - Unity Banner Delegate Methods

- (void)unityAdsBannerDidClick:(nonnull NSString *)placementId {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (strongNetworkConnector) {
    [strongNetworkConnector adapterDidGetAdClick:self];
    [strongNetworkConnector adapterWillLeaveApplication:self];
  }
}

- (void)unityAdsBannerDidError:(nonnull NSString *)message {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (strongNetworkConnector) {
    NSError *error = GADUnityErrorWithDescription(@"Unity Ads Banner internal error");
    [strongNetworkConnector adapter:self didFailAd:error];
  }
}

- (void)unityAdsBannerDidHide:(nonnull NSString *)placementId {
  NSLog(@"Unity Ads Banner did hide.");
}

- (void)unityAdsBannerDidLoad:(nonnull NSString *)placementId view:(nonnull UIView *)view {
  id<GADMAdNetworkConnector> strongNetworkConnector = _networkConnector;
  if (strongNetworkConnector) {
    [strongNetworkConnector adapter:self didReceiveAdView:view];
  } else {
    NSLog(@"ERROR: Network connector for UnityAds banner adapter not found.");
  }
}

- (void)unityAdsBannerDidShow:(nonnull NSString *)placementId {
  NSLog(@"Unity Ads Banner is showing.");
}

- (void)unityAdsBannerDidUnload:(nonnull NSString *)placementId {
  NSLog(@"Unity Ads Banner has unloaded.");
}

@end
