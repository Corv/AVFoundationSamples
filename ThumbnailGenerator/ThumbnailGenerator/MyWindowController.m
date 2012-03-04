//
//  MyWindowController.m
//  ThumbnailGenerator
//
//  Created by Andrew Pangborn on 3/2/12.
//

#import "MyWindowController.h"

@implementation MyWindowController

@synthesize videoTrack = _videoTrack;
@synthesize videoAsset = _videoAsset;
@synthesize videoPlayer = _videoPlayer;
@synthesize videoLayer = _videoLayer;
@synthesize imageGenerator = _imageGenerator;
@synthesize isPlaying, isCreatingImage, thumbWidth, thumbHeight, thumbCols, thumbRows, thumbMargin, thumbSpacing, progress, progressMax;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        self.thumbWidth = 160;
        self.thumbHeight = 90;
        self.thumbRows = 6;
        self.thumbCols = 4;
        self.thumbMargin = 20;
        self.thumbSpacing = 10;
        self.progressMax = 0;
        self.progress = 0;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

#pragma mark Rendering
- (void) saveFramesToURL:(NSURL*)url {
    double timestamp = 0.0;
    int numFrames = thumbRows * thumbCols;
    self.progressMax = numFrames;
    double interval = duration/(double)numFrames;
    
    // set the tolerences to the frame interval
    [self.imageGenerator setRequestedTimeToleranceBefore:CMTimeMake(interval*1000, 1000)];
    [self.imageGenerator setRequestedTimeToleranceAfter:CMTimeMake(interval*1000, 1000)];
    self->timeStarted = CFAbsoluteTimeGetCurrent();
    
    NSLog(@"Movie Length: %f, interval: %f, %d total frames",duration,interval,numFrames);
    idst = CGImageDestinationCreateWithURL((CFURLRef)url, kUTTypeJPEG, 1, NULL);
    
    NSMutableArray* times = [NSMutableArray arrayWithCapacity:numFrames];
    for(int f = 0; f < numFrames; f++) {
        [times addObject:[NSValue valueWithCMTime:CMTimeMake((int)(timestamp*1000), 1000)]];
        timestamp += interval;
    }
    
    int imageWidth = thumbMargin*2 + thumbSpacing*(thumbCols-1) + thumbWidth*thumbCols;
    int imageHeight = thumbMargin*2 + thumbSpacing*(thumbRows-1) + thumbHeight*thumbRows;
    __block UInt8* data = malloc(imageWidth * imageHeight * 4);
    __block CGContextRef context = CGBitmapContextCreate(data, imageWidth, imageHeight, 8, imageWidth*4, (CGColorSpaceRef)[(id)CGColorSpaceCreateWithName(kCGColorSpaceSRGB) autorelease], kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGFloat gray[4] = {0.8,0.8,0.8,1.0};
    CGContextSetFillColor(context, gray);
    CGContextFillRect(context, CGRectMake(0, 0, imageWidth, imageHeight));
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            NSString *requestedTimeString = (NSString *)CMTimeCopyDescription(NULL, requestedTime);
            NSString *actualTimeString = (NSString *)CMTimeCopyDescription(NULL, actualTime);
            NSLog(@"Requested: %@; actual %@", requestedTimeString, actualTimeString);
            [requestedTimeString release];
            [actualTimeString release];
            
            int rowIndex = _framesComplete / thumbCols;
            int colIndex = _framesComplete % thumbCols;
            
            int x = thumbMargin + colIndex * thumbWidth + thumbSpacing * colIndex;
            int y = imageHeight - (thumbMargin + (rowIndex+1) * thumbHeight + thumbSpacing  * rowIndex);
            CGRect imgRect = CGRectMake(x, y, thumbWidth, thumbHeight);
            CGContextDrawImage(context, imgRect, image);
            
            _framesComplete += 1; // atomic property
            self.progress = _framesComplete;
            
            // Once all frames are decoded and drawn into the context, rendering the final JPEG
            if(_framesComplete == numFrames) {
                if(idst) {
                    CGImageRef finalImage = CGBitmapContextCreateImage(context);
                    if(finalImage) {
                        CGImageDestinationAddImage(idst, finalImage, NULL);
                        NSLog(@"All video thumbnails decoded, beginning image encoding");
                        CGImageDestinationFinalize(idst);
                        NSLog(@"Image Creation Complete!");
                        CFRelease(finalImage);
                    }
                    CFRelease(idst);
                    idst = NULL;
                }
                self.isCreatingImage = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->createThumbnailsButton setTitle:@"Create Thumbnails"];
                });
                CGContextRelease(context);
                free(data);
            }
        } else if (result == AVAssetImageGeneratorFailed) {
            NSLog(@"Failed with error: %@", [error localizedDescription]);
        } else if (result == AVAssetImageGeneratorCancelled) {
            NSLog(@"Canceled");
        }
    }];
}

#pragma mark Playback

-(void) playVideo {
    // play the video...
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CALayer* superlayer = [self->videoView layer];
        self.videoLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
        [self.videoLayer setFrame:NSRectToCGRect([self->videoView bounds])];
        self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [superlayer addSublayer:self.videoLayer];
        [self.videoPlayer play];
        self.isPlaying = YES;
        self.progressMax = duration;
        [self.videoPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:NULL usingBlock:^(CMTime time) {
            self.progress = (int) CMTimeGetSeconds(time);
        }];
    });
}

-(void) stopVideo {
    // stop playback...
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.videoPlayer pause];
        self.isPlaying = NO;
        [self.videoLayer removeFromSuperlayer];
        self.videoLayer = nil;
    });
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
                                [self->createThumbnailsButton setEnabled:YES];
                                [[self window] setTitle:[NSString stringWithFormat:@"Video Thumbnail Generator - %@",[url lastPathComponent]]];
                                
                                if(self->shouldPlay) {
                                    [self playVideo];
                                    [self->previewButton setTitle:@"Stop Video"];
                                } else {
                                    [self->previewButton setTitle:@"Preview Video"];
                                }
                            });
                        }
                    }];
                }
            } else {
                // show error, not playable
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[NSAlert alertWithMessageText:@"The video is not playable" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"The video cannot be decoded. Likely the container format or codec is not supported by AVFoundation"] runModal];
                    [self->createThumbnailsButton setEnabled:NO];
                    [[self window] setTitle:[NSString stringWithFormat:@"Video Thumbnail Generator"]];
                });
            }
        }];
        
    }];
}

-(IBAction)previewVideo:(id)sender {
    self->shouldPlay = YES;
    if(!self.videoPlayer) {
        // attempt to open a video and start playing it
        [self open:self];
    } else {
        if(isPlaying) {
            [self stopVideo];
            [self->previewButton setTitle:@"Preview Video"];
        } else {
            [self playVideo];
            [self->previewButton setTitle:@"Stop Video"];
        }
    }
}

-(IBAction)createThumbnails:(id)sender {
    if(!isCreatingImage) {
        [self stopVideo];
        [self->previewButton setTitle:@"Preview Video"];
        _framesComplete = 0;
        
        if(self.imageGenerator) {
            NSSavePanel* sp = [NSSavePanel savePanel];
            [sp setDirectoryURL:nil];
            [sp setAllowedFileTypes:[NSArray arrayWithObjects:(id)kUTTypeImage,nil]];
            [sp beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
                if(result == NSFileHandlingPanelOKButton) {
                    NSURL* url = [sp URL];
                    
                    // Make sure thumbnail dimensions match the aspect ratio of the video to avoid distortion
                    CGFloat videoWidth = self.videoAsset.naturalSize.width;
                    CGFloat videoHeight = self.videoAsset.naturalSize.height;
                    CGFloat videoAspectRatio = videoWidth / videoHeight;
                    
                    if(videoAspectRatio != (self.thumbWidth) / ((CGFloat)self.thumbHeight)) {
                        NSLog(@"Adjusting aspect ratio of thumbnail to match video\n");
                        int maxDimension = MAX(self.thumbWidth,self.thumbHeight);
                        self.thumbWidth = maxDimension;
                        self.thumbHeight = maxDimension / videoAspectRatio + 0.5;
                    }
                    
                    NSLog(@"Creating Preview with %d x %d images, %d x %d pixels each\n",thumbRows,thumbCols,thumbWidth,thumbCols);
                    [self saveFramesToURL:url];
                    self.isCreatingImage = YES;
                    [self->createThumbnailsButton setTitle:@"Abort Thumbnail Creation"];
                }
            }];
        } else {
            [[NSAlert alertWithMessageText:@"You must first open a video" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Open a playable video with File --> Open or by clicking the \"Open Video\" button"] runModal];
        }
    } else {
        [self.imageGenerator cancelAllCGImageGeneration];
        [self->createThumbnailsButton setTitle:@"Create Thumbnails"];
        self.isCreatingImage = NO;
        
        if(self->idst)
            CFRelease(self->idst);
        self->idst = nil;
    }
}

-(void) dealloc {
    [self->_videoAsset release];
    [self->_videoTrack release];
    [self->_videoLayer release];
    [self->_videoPlayer release];
    [self->_imageGenerator release];
    
    if(self->idst)
        CFRelease(self->idst);
    
    [super dealloc];
}

@end
