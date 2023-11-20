//
//  NowPlayingManager.m
//  RCTVideo-tvOS
//
//  Created by Maksym Pozychenko on 19.11.2023.
//

#import "NowPlayingManager.h"
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <AVFoundation/AVFoundation.h>

@import MediaPlayer;

@interface NowPlayingManager ()

@property (nonatomic, copy) NSString *artworkUrl;

@end

#define MEDIA_STATE_PLAYING @"STATE_PLAYING"
#define MEDIA_STATE_PAUSED @"STATE_PAUSED"
#define MEDIA_STATE_STOPPED @"STATE_STOPPED"
#define MEDIA_STATE_ERROR @"STATE_ERROR"
#define MEDIA_STATE_BUFFERING @"STATE_BUFFERING"
#define MEDIA_STATE_RATING_PERCENTAGE @"STATE_RATING_PERCENTAGE"
#define MEDIA_SPEED @"speed"
#define MEDIA_STATE @"state"
#define MEDIA_DICT @{@"persistentID": MPMediaItemPropertyPersistentID, \
    @"duration": MPMediaItemPropertyPlaybackDuration, \
    @"title": MPMediaItemPropertyTitle, \
    @"externalContentID": MPNowPlayingInfoPropertyExternalContentIdentifier, \
    @"elapsedTime": MPNowPlayingInfoPropertyElapsedPlaybackTime, \
    @"playbackRate": MPNowPlayingInfoPropertyPlaybackRate, \
}




@implementation NowPlayingManager

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (NSDictionary *)constantsToExport
{
    return @{
        @"STATE_PLAYING": MEDIA_STATE_PLAYING,
        @"STATE_PAUSED": MEDIA_STATE_PAUSED,
        @"STATE_STOPPED" : MEDIA_STATE_STOPPED,
        @"STATE_ERROR" :MEDIA_STATE_ERROR,
        @"STATE_BUFFERING":MEDIA_STATE_BUFFERING,
        @"STATE_RATING_PERCENTAGE":MEDIA_STATE_RATING_PERCENTAGE,
    };
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(updatePlayback:(NSDictionary *) originalDetails)
{
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];

    if (center.nowPlayingInfo == nil) {
        return;
    }

    NSMutableDictionary *details = [originalDetails mutableCopy];
    NSString *state = [details objectForKey:MEDIA_STATE];

    // Set the playback rate from the state if no speed has been defined
    // If they provide the speed, then use it
    if (state != nil && [details objectForKey:MEDIA_SPEED] == nil) {
        NSNumber *speed = [state isEqual:MEDIA_STATE_PAUSED]
        ? [NSNumber numberWithDouble:0]
        : [NSNumber numberWithDouble:1];

        [details setValue:speed forKey:MEDIA_SPEED];
    }
    
    if ([state isEqual:MEDIA_STATE_PAUSED]) {
        [details setValue: [NSNumber numberWithInt:0] forKey: @"playbackRate"];
    } else if ([state isEqual:MEDIA_STATE_PLAYING]) {
        [details setValue: [NSNumber numberWithInt:1] forKey: @"playbackRate"];
    }

    NSMutableDictionary *mediaDict = [[NSMutableDictionary alloc] initWithDictionary: center.nowPlayingInfo];

    center.nowPlayingInfo = [self update:mediaDict with:details andSetDefaults:false];

    NSString *artworkUrl = [self getArtworkUrl:[originalDetails objectForKey:@"artwork"]];
    [self updateArtworkIfNeeded:artworkUrl];
}

RCT_EXPORT_METHOD(setNowPlaying:(NSDictionary *) details)
{
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *mediaDict = [NSMutableDictionary dictionary];


    center.nowPlayingInfo = [self update:mediaDict with:details andSetDefaults:true];

    NSString *artworkUrl = [self getArtworkUrl:[details objectForKey:@"artwork"]];
    [self updateArtworkIfNeeded:artworkUrl];
}

RCT_EXPORT_METHOD(resetNowPlaying)
{
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    center.nowPlayingInfo = nil;
    self.artworkUrl = nil;
}


RCT_EXPORT_METHOD(stopControl){
    [self stop];
}

- (id)init {
    self = [super init];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    return self;
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (void)dealloc {
    [self stop];
}

- (void)stop {
    MPRemoteCommandCenter *remoteCenter = [MPRemoteCommandCenter sharedCommandCenter];
    [self resetNowPlaying];
}


- (NSString*)getArtworkUrl:(NSString*)artwork {
  NSString *artworkUrl = nil;

  if (artwork) {
      if ([artwork isKindOfClass:[NSString class]]) {
           artworkUrl = artwork;
      } else if ([[artwork valueForKey: @"uri"] isKindOfClass:[NSString class]]) {
           artworkUrl = [artwork valueForKey: @"uri"];
      }
  }

  return artworkUrl;
}

- (void)updateArtworkIfNeeded:(id)artworkUrl
{
    if( artworkUrl == nil ) {
        return;
    }
    
    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
    if ([artworkUrl isEqualToString:self.artworkUrl] && [center.nowPlayingInfo objectForKey:MPMediaItemPropertyArtwork] != nil) {
        return;
    }
    
    self.artworkUrl = artworkUrl;
    
    // Custom handling of artwork in another thread, will be loaded async
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        UIImage *image = nil;
        
        // check whether artwork path is present
        if ([artworkUrl isEqual: @""]) {
            return;
        }
        
        // artwork is url download from the interwebs
        if ([artworkUrl hasPrefix: @"http://"] || [artworkUrl hasPrefix: @"https://"]) {
            NSURL *imageURL = [NSURL URLWithString:artworkUrl];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            image = [UIImage imageWithData:imageData];
        } else {
            NSString *localArtworkUrl = [artworkUrl stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:localArtworkUrl];
            if (fileExists) {
                image = [UIImage imageNamed:localArtworkUrl];
            }
        }
        
        // Check if image was available otherwise don't do anything
        if (image == nil) {
            return;
        }
        
        // check whether image is loaded
        CGImageRef cgref = [image CGImage];
        CIImage *cim = [image CIImage];
        
        if (cim == nil && cgref == NULL) {
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Check if URL wasn't changed in the meantime
            if (![artworkUrl isEqual:self.artworkUrl]) {
                return;
            }
            
            MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
            MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
            NSMutableDictionary *mediaDict = (center.nowPlayingInfo != nil) ? [[NSMutableDictionary alloc] initWithDictionary: center.nowPlayingInfo] : [NSMutableDictionary dictionary];
            [mediaDict setValue:artwork forKey:MPMediaItemPropertyArtwork];
            center.nowPlayingInfo = mediaDict;
        });
    });
}

- (NSDictionary *) update:(NSMutableDictionary *) mediaDict with:(NSDictionary *) details andSetDefaults:(BOOL) setDefault {
    if(@available (tvOS 10.0, *)) {
        for (NSString *key in MEDIA_DICT) {
            if ([details objectForKey:key] != nil) {
                [mediaDict setValue:[details objectForKey:key] forKey:[MEDIA_DICT objectForKey:key]];
            }
            
            // In iOS Simulator, always include the MPNowPlayingInfoPropertyPlaybackRate key in your nowPlayingInfo dictionary
            // only if we are creating a new dictionary
            if ([key isEqualToString:MEDIA_SPEED] && [details objectForKey:key] == nil && setDefault) {
                [mediaDict setValue:[NSNumber numberWithDouble:1] forKey:[MEDIA_DICT objectForKey:key]];
            }
        }
    }

    return mediaDict;
}

@end
