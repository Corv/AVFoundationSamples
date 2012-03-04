//
//  MyWindowController.h
//  ThumbnailGenerator
//
//  Created by Andrew Pangborn on 3/2/12.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <ApplicationServices/ApplicationServices.h>

@interface MyWindowController : NSWindowController
{
    double                 duration; // seconds
    
    AVAssetImageGenerator* imageGenerator;
    CGImageDestinationRef  idst;
    int _framesComplete;
    AVAsset* _videoAsset;
    AVAssetTrack* _videoTrack;
    AVPlayer* _videoPlayer;
    AVPlayerLayer* _videoLayer;
    AVAssetImageGenerator* _imageGenerator;
    BOOL shouldPlay;
    BOOL isPlaying;
    BOOL isCreatingImage;
    double timeStarted;
    int thumbWidth;
    int thumbHeight;
    int thumbRows;
    int thumbCols;
    int thumbMargin;
    int thumbSpacing;
    
    IBOutlet NSButton* previewButton;
    IBOutlet NSButton* createThumbnailsButton;
    IBOutlet NSView* videoView;
    IBOutlet NSTextField* videoTimeLabel;
}

@property (assign) int progress;
@property (assign) int progressMax;

@property (retain) AVAsset* videoAsset;
@property (retain) AVAssetTrack* videoTrack;
@property (retain) AVPlayer* videoPlayer;
@property (retain) AVPlayerLayer* videoLayer;
@property (retain) AVAssetImageGenerator* imageGenerator;

@property (assign) BOOL isPlaying;
@property (assign) BOOL isCreatingImage;

@property (assign) int thumbWidth;
@property (assign) int thumbHeight;
@property (assign) int thumbRows;
@property (assign) int thumbCols;
@property (assign) int thumbMargin;
@property (assign) int thumbSpacing;

@end
