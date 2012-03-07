//
//  MyWindowController.m
//  AnimatedGIFCreator
//
//  Created by Andrew Pangborn on 2/11/12.
//

#import "MyWindowController.h"
#import <CoreServices/CoreServices.h>

@implementation MyWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        self.framesComplete = 0;
        self->shouldPlay = NO;
        self->showImages = YES;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file
}

@synthesize framesComplete = _framesComplete;
@synthesize videoTrack = _videoTrack;
@synthesize videoAsset = _videoAsset;
@synthesize videoPlayer = _videoPlayer;
@synthesize videoLayer = _videoLayer;
@synthesize imageGenerator = _imageGenerator;
@synthesize isPlaying;
@synthesize isCreatingGif;

- (void) saveFramesWithInterval:(double)interval toURL:(NSURL*)url {
    double timestamp = 0.0;
    int numFrames = ceil(duration / interval);
    
    // set the tolerences to the frame interval
    [self.imageGenerator setRequestedTimeToleranceBefore:CMTimeMake(interval*1000, 1000)];
    [self.imageGenerator setRequestedTimeToleranceAfter:CMTimeMake(interval*1000, 1000)];
    [self->progressIndicator setMinValue:0.0];
    [self->progressIndicator setMaxValue:(double)numFrames];
    self->framesTotalLabel.stringValue = [NSString stringWithFormat:@"%d",numFrames];
    self->timeStarted = CFAbsoluteTimeGetCurrent();
    
    NSLog(@"Movie Length: %f, interval: %f, %d total frames",duration,interval,numFrames);
    NSDictionary* properties = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:(id)[NSNumber numberWithDouble:interval],(id)kCGImagePropertyGIFDelayTime, nil] forKey:(id)kCGImagePropertyGIFDictionary];
    gifDestination = CGImageDestinationCreateWithURL((CFURLRef)url, kUTTypeGIF, numFrames, (CFDictionaryRef)properties);
    
    NSMutableArray* times = [NSMutableArray arrayWithCapacity:numFrames];
    for(int f = 0; f < numFrames; f++) {
        [times addObject:[NSValue valueWithCMTime:CMTimeMake((int)(timestamp*1000), 1000)]];
        timestamp += interval;
    }
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            NSString *requestedTimeString = (NSString *)CMTimeCopyDescription(NULL, requestedTime);
            NSString *actualTimeString = (NSString *)CMTimeCopyDescription(NULL, actualTime);
            NSLog(@"Requested: %@; actual %@", requestedTimeString, actualTimeString);
            [requestedTimeString release];
            [actualTimeString release];
            
            if(gifDestination) 
                CGImageDestinationAddImage(gifDestination, image, (CFDictionaryRef)properties);
            self.framesComplete += 1; // atomic property
            
            // Update the image preview and progress on the main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                if(showImages) {
                    [self->imageView layer].contents = (id)image;
                    [self->imageView setNeedsDisplay:YES];
                }
                [self->progressIndicator setDoubleValue:self.framesComplete];
                self->framesCompleteLabel.stringValue = [NSString stringWithFormat:@"%d",self.framesComplete];
                self->elapsedTimeLabel.stringValue = [NSString stringWithFormat:@"%.2f",CFAbsoluteTimeGetCurrent()-self->timeStarted];
                self->fpsLabel.stringValue = [NSString stringWithFormat:@"%.2f",self.framesComplete/(CFAbsoluteTimeGetCurrent()-self->timeStarted)];
            });
            
            // Once all frames are decoded, finalize the Animated GIF
            if(self.framesComplete == numFrames) {
                if(gifDestination) {
                    NSLog(@"All video thumbnails decoded, beginning GIF encoding - this may take awhile.\n");
                    CGImageDestinationFinalize(gifDestination);
                    CFRelease(gifDestination);
                    gifDestination = NULL;
                    NSLog(@"Image Creation Complete!");
                }
            }
        } else if (result == AVAssetImageGeneratorFailed) {
            NSLog(@"Failed with error: %@", [error localizedDescription]);
        } else if (result == AVAssetImageGeneratorCancelled) {
            NSLog(@"Canceled");
        }
    }];
}

-(void) playVideo {
    // play the video...
    CALayer* superlayer = [self->videoView layer];
    self.videoLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
    [self.videoLayer setFrame:NSRectToCGRect([self->videoView bounds])];
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [superlayer addSublayer:self.videoLayer];
    [self.videoPlayer play];
    self.isPlaying = YES;
    [self.videoPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
        double seconds = CMTimeGetSeconds(time);
        self->videoTimeLabel.stringValue = [NSString stringWithFormat:@"%d",(int)seconds];
    }];
}

-(void) stopVideo {
    // stop playback...
    [self.videoPlayer pause];
    self.isPlaying = NO;
    [self.videoLayer removeFromSuperlayer];
    self.videoLayer = nil;
}

#pragma mark Actions
- (IBAction)open:(id)sender
{
    NSOpenPanel* op = [NSOpenPanel openPanel];
    [op setDirectoryURL:nil];
    [op setAllowedFileTypes:[NSArray arrayWithObjects:AVFileTypeAppleM4V,AVFileTypeMPEG4,AVFileTypeQuickTimeMovie,nil]];
    [op beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        // Open Movie...
        NSURL* url = [op URL];
        //AVFileTypeAppleM4A
        self.videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        NSArray *keys = [NSArray arrayWithObject:@"playable"];
        [self.videoAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
            AVKeyValueStatus playableStatus = [self.videoAsset statusOfValueForKey:@"playable" error:nil];
            
            if(playableStatus == AVKeyValueStatusLoaded) {
                // video is playable, get the tracks to determine the duration
                AVKeyValueStatus status = [self.videoAsset statusOfValueForKey:@"tracks" error:nil];
                if(status != AVKeyValueStatusLoaded) {
                    NSArray* keys = [NSArray arrayWithObject:@"tracks"];
                    [self.videoAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
                        self.videoTrack = [[self.videoAsset tracks] objectAtIndex:0];
                        if(self.videoTrack) {
                            self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.videoAsset];

                            CMTime endTime = CMTimeRangeGetEnd(self.videoTrack.timeRange);
                            duration = (endTime.value) / (double)(endTime.timescale);
                            
                            AVPlayerItem* playerItem = [AVPlayerItem playerItemWithAsset:self.videoAsset];
                            self.videoPlayer = [AVPlayer playerWithPlayerItem:playerItem];
                            
                            dispatch_async(dispatch_get_main_queue(), ^(void) {
                                [self->createGifButton setEnabled:YES];
                                [[self window] setTitle:[NSString stringWithFormat:@"AnimatedGIFCreator - %@",[url lastPathComponent]]];
                                
                                if(self->shouldPlay) {
                                    [self playVideo];
                                }
                            });
                        }
                    }];
                }
            } else {
                // show error, not playable
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[NSAlert alertWithMessageText:@"The video is not playable" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"The video cannot be decoded. Likely the container format or codec is not supported by AVFoundation"] runModal];
                    [self->createGifButton setEnabled:NO];
                    [[self window] setTitle:[NSString stringWithFormat:@"AnimatedGIFCreator"]];
                });
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self->progressIndicator setDoubleValue:0];
                [self->framesCompleteLabel setStringValue:@"0"];
                [self->framesTotalLabel setStringValue:@"0"];
            });
        }];
                                                          
    }];
}

-(IBAction)createAnimatedGIF:(id)sender {
    if(!isCreatingGif) {
        [self stopVideo];
        self.framesComplete = 0;
        [self->progressIndicator setDoubleValue:0];
        [self->framesCompleteLabel setStringValue:@"0"];
        [self->framesTotalLabel setStringValue:@"0"];
        
        if(self.imageGenerator) {
            NSSavePanel* sp = [NSSavePanel savePanel];
            [sp setDirectoryURL:nil];
            [sp setAllowedFileTypes:[NSArray arrayWithObjects:(id)kUTTypeGIF, nil]];
            [sp beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
                if(result == NSFileHandlingPanelOKButton) {
                    NSURL* url = [sp URL];
                    double fps = [fpsField doubleValue];
                    if(fps > 0) {
                        [self saveFramesWithInterval:1.0/fps toURL:url];
                        self.isCreatingGif = YES;
                        [self->createGifButton setTitle:@"Abort GIF Creation"];
                    }
                }
            }];
        } else {
            [[NSAlert alertWithMessageText:@"You must first open a video" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Open a playable video with File --> Open or by hitting \"Preview Video\""] runModal];
        }
    } else {
        [self.imageGenerator cancelAllCGImageGeneration];
        [self->createGifButton setTitle:@"Create Animated GIF"];
        self.isCreatingGif = NO;
        
        if(self->gifDestination)
            CFRelease(self->gifDestination);
        self->gifDestination = nil;
    }
}

-(IBAction)previewVideo:(id)sender {
    self->shouldPlay = YES;
    if(!self.videoPlayer) {
        // attempt to open a video and start playing it
        [self open:self];
    } else {
        if(isPlaying) {
            [self.videoPlayer pause];
            [self.videoLayer removeFromSuperlayer];
            self.videoLayer = nil;
            self.videoPlayer = nil;
            [self->previewButton setTitle:@"Preview Video"];
        } else {
            [self playVideo];
            [self->previewButton setTitle:@"Stop Video"];
        }
    }
}

-(IBAction)showFramesCheckboxModified:(id)sender {
    if(sender == self->showImagesCheckbox) {
        self->showImages = (BOOL)[sender intValue];
    }
}

-(void) dealloc {
    [self->_videoAsset release];
    [self->_videoTrack release];
    [self->_videoLayer release];
    [self->_videoPlayer release];
    [self->_imageGenerator release];
    
    if(self->gifDestination)
        CFRelease(self->gifDestination);
    
    [super dealloc];
}

@end
