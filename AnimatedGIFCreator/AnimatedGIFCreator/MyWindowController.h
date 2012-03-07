//
//  MyWindowController.h
//  AnimatedGIFCreator
//
//  Created by Andrew Pangborn on 2/11/12.
//

#import <Cocoa/Cocoa.h>
#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface MyWindowController : NSWindowController
{
    double                 duration; // seconds

    AVAssetImageGenerator* imageGenerator;

    CGImageDestinationRef  gifDestination;
    int _framesComplete;
    AVAsset* _videoAsset;
    AVAssetTrack* _videoTrack;
    AVPlayer* _videoPlayer;
    AVPlayerLayer* _videoLayer;
    AVAssetImageGenerator* _imageGenerator;
    BOOL shouldPlay;
    BOOL isPlaying;
    BOOL isCreatingGif;
    BOOL showImages;
    double timeStarted;
    
    IBOutlet NSView* imageView;
    IBOutlet NSView* videoView;
    IBOutlet NSTextField* fpsField;
    IBOutlet NSProgressIndicator* progressIndicator;
    IBOutlet NSTextField* framesCompleteLabel;
    IBOutlet NSTextField* framesTotalLabel;
    IBOutlet NSTextField* videoTimeLabel;
    IBOutlet NSTextField* elapsedTimeLabel;
    IBOutlet NSTextField* fpsLabel;
    IBOutlet NSButton* previewButton;
    IBOutlet NSButton* createGifButton;
    IBOutlet NSButton* showImagesCheckbox;
}

@property (assign) int framesComplete;
@property (retain) AVAsset* videoAsset;
@property (retain) AVAssetTrack* videoTrack;
@property (retain) AVPlayer* videoPlayer;
@property (retain) AVPlayerLayer* videoLayer;
@property (retain) AVAssetImageGenerator* imageGenerator;
@property (assign) BOOL isPlaying;
@property (assign) BOOL isCreatingGif;

-(IBAction)createAnimatedGIF:(id)sender;
-(IBAction)showFramesCheckboxModified:(id)sender;

@end
