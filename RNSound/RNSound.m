#import "RNSound.h"

#if __has_include("RCTUtils.h")
#import "RCTUtils.h"
#else
#import <React/RCTUtils.h>
#endif
#import <CommonCrypto/CommonDigest.h>

@implementation RNSound {
    NSMutableDictionary* _playerPool;
    NSMutableDictionary* _callbackPool;
    
    NSString *_cacheNamespace;
}
    
    @synthesize _key = _key;
    
#pragma mark - Supporting Methods
// Gets the base NSCachesDirectory path
+(NSString *)cachesDirectoryName{
    static NSString *cachePath = nil;
    if(!cachePath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        cachePath = [paths objectAtIndex:0];
    }
    
    return cachePath;
}

// Builds paths for identifiers in the cache directory
+(NSString *)pathForName:(NSString *)name {
    NSString *cachePath = [self cachesDirectoryName];
    NSString *path = [cachePath stringByAppendingPathComponent:name];
    return path;
}
    
#pragma mark - NSData Cache methods
    
// Saves the given data to the cache directory
+(void)saveToCacheDirectory:(NSData *)data withName:(NSString *)name{
    NSString *path = [self pathForName:name];
    [data writeToFile:path atomically:YES];
}

// Returns the cached data with the given name; otherwise, returns false
+(BOOL)cacheExists:(NSString *)name{
    NSString *path = [self pathForName:name];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    return fileExists;
}
    
    
+(NSURL*)getCachedFileForURL:(NSURL *)url {
    NSData *urlData = [[url absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(urlData.bytes, (CC_LONG)urlData.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    [output appendFormat:@".%@", [url pathExtension]];
    
    NSString* name = [NSString stringWithString:output];
    
    if(![self cacheExists:name]) {
        NSData* data = [NSData dataWithContentsOfURL:url];
        [self saveToCacheDirectory:data withName: name];
    }
    
    
    NSString* path = [self pathForName:name];
    return [NSURL fileURLWithPath:path];
}
    
    
- (void)audioSessionChangeObserver:(NSNotification *)notification{
    NSDictionary* userInfo = notification.userInfo;
    AVAudioSessionRouteChangeReason audioSessionRouteChangeReason = [userInfo[@"AVAudioSessionRouteChangeReasonKey"] longValue];
    AVAudioSessionInterruptionType audioSessionInterruptionType   = [userInfo[@"AVAudioSessionInterruptionTypeKey"] longValue];
    AVAudioPlayer* player = [self playerForKey:self._key];
    if (audioSessionRouteChangeReason == AVAudioSessionRouteChangeReasonNewDeviceAvailable){
        if (player) {
            [player play];
        }
    }
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeEnded){
        if (player && player.isPlaying) {
            [player play];
        }
    }
    if (audioSessionRouteChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable){
        if (player) {
            [player pause];
        }
    }
    if (audioSessionInterruptionType == AVAudioSessionInterruptionTypeBegan){
        if (player) {
            [player pause];
        }
    }
}
    
-(NSMutableDictionary*) playerPool {
    if (!_playerPool) {
        _playerPool = [NSMutableDictionary new];
    }
    return _playerPool;
}
    
-(NSMutableDictionary*) callbackPool {
    if (!_callbackPool) {
        _callbackPool = [NSMutableDictionary new];
    }
    return _callbackPool;
}
    
-(AVAudioPlayer*) playerForKey:(nonnull NSNumber*)key {
    return [[self playerPool] objectForKey:key];
}
    
-(NSNumber*) keyForPlayer:(nonnull AVAudioPlayer*)player {
    return [[[self playerPool] allKeysForObject:player] firstObject];
}
    
-(RCTResponseSenderBlock) callbackForKey:(nonnull NSNumber*)key {
    return [[self callbackPool] objectForKey:key];
}
    
-(NSString *) getDirectory:(int)directory {
    return [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
}
    
-(void) audioPlayerDidFinishPlaying:(AVAudioPlayer*)player
                       successfully:(BOOL)flag {
    NSNumber* key = [self keyForPlayer:player];
    if (key == nil) return;
    
    @synchronized(key) {
        [self setOnPlay:NO forPlayerKey:key];
        RCTResponseSenderBlock callback = [self callbackForKey:key];
        if (callback) {
            callback(@[@(flag)]);
            [[self callbackPool] removeObjectForKey:key];
        }
    }
}
    
    RCT_EXPORT_MODULE();
    
-(NSArray<NSString *> *)supportedEvents
    {
        return @[@"onPlayChange"];
    }
    
-(NSDictionary *)constantsToExport {
    return @{@"IsAndroid": [NSNumber numberWithBool:NO],
             @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
             @"NSDocumentDirectory": [self getDirectory:NSDocumentDirectory],
             @"NSLibraryDirectory": [self getDirectory:NSLibraryDirectory],
             @"NSCachesDirectory": [self getDirectory:NSCachesDirectory],
             };
}
    
    RCT_EXPORT_METHOD(enable:(BOOL)enabled) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory: AVAudioSessionCategoryAmbient error: nil];
        [session setActive: enabled error: nil];
    }
    
    RCT_EXPORT_METHOD(setActive:(BOOL)active) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive: active error: nil];
    }
    
    RCT_EXPORT_METHOD(setMode:(NSString *)modeName) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSString *mode = nil;
        
        if ([modeName isEqual: @"Default"]) {
            mode = AVAudioSessionModeDefault;
        } else if ([modeName isEqual: @"VoiceChat"]) {
            mode = AVAudioSessionModeVoiceChat;
        } else if ([modeName isEqual: @"VideoChat"]) {
            mode = AVAudioSessionModeVideoChat;
        } else if ([modeName isEqual: @"GameChat"]) {
            mode = AVAudioSessionModeGameChat;
        } else if ([modeName isEqual: @"VideoRecording"]) {
            mode = AVAudioSessionModeVideoRecording;
        } else if ([modeName isEqual: @"Measurement"]) {
            mode = AVAudioSessionModeMeasurement;
        } else if ([modeName isEqual: @"MoviePlayback"]) {
            mode = AVAudioSessionModeMoviePlayback;
        } else if ([modeName isEqual: @"SpokenAudio"]) {
            mode = AVAudioSessionModeSpokenAudio;
        }
        
        if (mode) {
            [session setMode: mode error: nil];
        }
    }
    
    RCT_EXPORT_METHOD(setCategory:(NSString *)categoryName
                      mixWithOthers:(BOOL)mixWithOthers) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSString *category = nil;
        
        if ([categoryName isEqual: @"Ambient"]) {
            category = AVAudioSessionCategoryAmbient;
        } else if ([categoryName isEqual: @"SoloAmbient"]) {
            category = AVAudioSessionCategorySoloAmbient;
        } else if ([categoryName isEqual: @"Playback"]) {
            category = AVAudioSessionCategoryPlayback;
        } else if ([categoryName isEqual: @"Record"]) {
            category = AVAudioSessionCategoryRecord;
        } else if ([categoryName isEqual: @"PlayAndRecord"]) {
            category = AVAudioSessionCategoryPlayAndRecord;
        }
#if TARGET_OS_IOS
        else if ([categoryName isEqual: @"AudioProcessing"]) {
            category = AVAudioSessionCategoryAudioProcessing;
        }
#endif
        else if ([categoryName isEqual: @"MultiRoute"]) {
            category = AVAudioSessionCategoryMultiRoute;
        }
        
        if (category) {
            if (mixWithOthers) {
                [session setCategory: category withOptions:AVAudioSessionCategoryOptionMixWithOthers error: nil];
            } else {
                [session setCategory: category error: nil];
            }
        }
    }
    
    RCT_EXPORT_METHOD(enableInSilenceMode:(BOOL)enabled) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory: AVAudioSessionCategoryPlayback error: nil];
        [session setActive: enabled error: nil];
    }
    
    RCT_EXPORT_METHOD(prepare:(NSString*)fileName
                      withKey:(nonnull NSNumber*)key
                      withOptions:(NSDictionary*)options
                      withCallback:(RCTResponseSenderBlock)callback) {
        NSError* error;
        NSURL* fileNameUrl;
        AVAudioPlayer* player;
        
        if ([fileName hasPrefix:@"http"]) {
            fileNameUrl = [NSURL URLWithString:fileName];
            
            NSURL* url = [RNSound getCachedFileForURL:fileNameUrl];
            
            NSError *error;
            player = [[AVAudioPlayer alloc]
                      initWithContentsOfURL:url
                      error:&error];
            
            //    player = [[AVAudioPlayer alloc] initWithData:bgAudioData error:&error];
        }
        else if ([fileName hasPrefix:@"ipod-library://"]) {
            fileNameUrl = [NSURL URLWithString:fileName];
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileNameUrl error:&error];
        }
        else {
            fileNameUrl = [NSURL URLWithString: fileName];
            player = [[AVAudioPlayer alloc]
                      initWithContentsOfURL:fileNameUrl
                      error:&error];
        }
        
        if (player) {
            player.delegate = self;
            player.enableRate = YES;
            [player prepareToPlay];
            [[self playerPool] setObject:player forKey:key];
            callback(@[[NSNull null], @{@"duration": @(player.duration),
                                        @"numberOfChannels": @(player.numberOfChannels)}]);
        } else {
            callback(@[RCTJSErrorFromNSError(error)]);
        }
    }
    
    RCT_EXPORT_METHOD(play:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionChangeObserver:) name:AVAudioSessionRouteChangeNotification object:nil];
        self._key = key;
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            [[self callbackPool] setObject:[callback copy] forKey:key];
            [player play];
            [self setOnPlay:YES forPlayerKey:key];
        }
    }
    
    RCT_EXPORT_METHOD(pause:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            [player pause];
            callback(@[]);
        }
    }
    
    RCT_EXPORT_METHOD(stop:(nonnull NSNumber*)key withCallback:(RCTResponseSenderBlock)callback) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            [player stop];
            player.currentTime = 0;
            callback(@[]);
        }
    }
    
    RCT_EXPORT_METHOD(release:(nonnull NSNumber*)key) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            [player stop];
            [[self callbackPool] removeObjectForKey:player];
            [[self playerPool] removeObjectForKey:key];
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter removeObserver:self];
        }
    }
    
    RCT_EXPORT_METHOD(setVolume:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            player.volume = [value floatValue];
        }
    }
    
    RCT_EXPORT_METHOD(setPan:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            player.pan = [value floatValue];
        }
    }
    
    RCT_EXPORT_METHOD(setNumberOfLoops:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            player.numberOfLoops = [value intValue];
        }
    }
    
    RCT_EXPORT_METHOD(setSpeed:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            player.rate = [value floatValue];
        }
    }
    
    
    RCT_EXPORT_METHOD(setCurrentTime:(nonnull NSNumber*)key withValue:(nonnull NSNumber*)value) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            player.currentTime = [value doubleValue];
        }
    }
    
    RCT_EXPORT_METHOD(getCurrentTime:(nonnull NSNumber*)key
                      withCallback:(RCTResponseSenderBlock)callback) {
        AVAudioPlayer* player = [self playerForKey:key];
        if (player) {
            callback(@[@(player.currentTime), @(player.isPlaying)]);
        } else {
            callback(@[@(-1), @(false)]);
        }
    }
    
+ (BOOL)requiresMainQueueSetup
    {
        return YES;
    }
- (void)setOnPlay:(BOOL)isPlaying forPlayerKey:(nonnull NSNumber*)playerKey {
    [self sendEventWithName:@"onPlayChange" body:@{@"isPlaying": isPlaying ? @YES : @NO, @"playerKey": playerKey}];
}
    @end
