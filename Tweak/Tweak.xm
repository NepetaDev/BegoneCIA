#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import "../BCCommon.h"

static BOOL bcActive = true;
static NSMutableArray *bcCaptureSessions = [[NSMutableArray alloc] initWithCapacity:250];
static NSMutableArray *bcLocationManagers = [[NSMutableArray alloc] initWithCapacity:250];

%hookf(OSStatus, AudioUnitProcess, AudioUnit unit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames, AudioBufferList *ioData) {
    if (bcActive) {
        AudioComponentDescription unitDescription = {0};
        AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &unitDescription);

        // Replaces microphone input with silence.
        if (unitDescription.componentSubType == 'agcc' || unitDescription.componentSubType == 'agc2') {
            if (inNumberFrames > 0) {
                inNumberFrames = 1;
                for (int i = 0; i < (*ioData).mNumberBuffers; i++) {
                    (*ioData).mBuffers[i].mDataByteSize = sizeof(float);
                    (*ioData).mBuffers[i].mData = (float *)malloc(sizeof(float));
                }
            }
        }
    }

    return %orig;
}

@interface CLLocationManager(BegoneCIA)
@property (nonatomic, retain) id bcDelegate;

-(void)bcUpdate;

@end


@interface AVCaptureSession(BegoneCIA)
@property (nonatomic, retain) NSMutableArray *bcInputs;

-(void)bcUpdate;

@end

%hook CLLocationManager

%property (nonatomic, retain) id bcDelegate;

-(id)delegate {
    if (bcActive) {
        return NULL;
    } else {
        return %orig;
    }
}

-(void)setDelegate:(id)arg1 {
    // If we remove the delegate then that given app won't receive location updates.

    if (arg1) self.bcDelegate = arg1;
    
    if (![bcLocationManagers containsObject:self]) {
        [bcLocationManagers addObject:self];
    }

    if (bcActive) {
        arg1 = NULL;
    }

    %orig;
}

-(CLLocation *)location {
    if (bcActive) {
        return NULL;
    } else {
        return %orig;
    }
}

%new
-(void)bcUpdate {
    if (!bcActive) {
        self.delegate = self.bcDelegate;
    } else {
        self.delegate = NULL;
    }
}

%end

// This kills the camera app :c
/*%hookf(CVImageBufferRef, CMSampleBufferGetImageBuffer, CMSampleBufferRef sbuf) {
    return NULL;
}*/

%hook AVCaptureSession

%property (nonatomic, retain) NSMutableArray *bcInputs;

-(void)addInput:(id)arg1 {
    // TODO: find a better way

    if (!self.bcInputs) {
        self.bcInputs = [[NSMutableArray alloc] initWithCapacity:250];
    }
    
    if (![bcCaptureSessions containsObject:self]) {
        [bcCaptureSessions addObject:self];
    }
    
    //if ([arg1 isKindOfClass:[AVCaptureDeviceInput class]]) {
        //AVCaptureDeviceInput *input = (AVCaptureDeviceInput *)arg1;
        //AVCaptureDevice *device = [input device];

        // We only want to block camera streams.
        // Microphone streams are properly handled by the mediaserverd hook.
        // I should hook the .mediacapture instead, but for now this will work.

        // Welp, it doesn't do what I wanted it to do, sadly.
        //if ([device hasMediaType:AVMediaTypeVideo] || [device hasMediaType:AVMediaTypeMuxed]) {
            if (![self.bcInputs containsObject:arg1]) [self.bcInputs addObject:arg1];

            if (!bcActive) {
                %orig;
            }
            //return;
        //}
    //}

    //%orig;
}

-(void)removeInput:(id)arg1 {
    if (!bcActive) [self.bcInputs removeObject:arg1];

    %orig;
}

%new
-(void)bcUpdate {
    if (!self.bcInputs) return;
    if (!bcActive) {
        for (id obj in self.bcInputs) {
            if (obj) [self addInput:obj];
        }
    } else {
        for (id obj in self.bcInputs) {
            if (obj) [self removeInput:obj];
        }
    }
}

%end

void HBCBPreferencesChanged() {
    bcActive = BCGetState();

    for (id obj in bcLocationManagers) {
        if (obj) {
            CLLocationManager *manager = (CLLocationManager *)obj;
            [manager bcUpdate];
        }
    }

    for (id obj in bcCaptureSessions) {
        if (obj) {
            AVCaptureSession *session = (AVCaptureSession *)obj;
            [session bcUpdate];
        }
    }
}

%ctor {
    HBCBPreferencesChanged();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBCBPreferencesChanged, (CFStringRef)BCNotification, NULL, kNilOptions);

    NSLog(@"[BegoneCIA] Loaded.");
    %init;
}