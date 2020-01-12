//
//  FICDViewController.m
//  FastImageCacheDemo
//
//  Copyright (c) 2013 Path, Inc.
//  See LICENSE for full license agreement.
//

#import "FICDViewController.h"
#import "FICImageCache.h"
#import "FICDTableView.h"
#import "FICDAppDelegate.h"
#import "FICDPhoto.h"
#import "FICDFullscreenPhotoDisplayController.h"
#import "FICDPhotosTableViewCell.h"

#pragma mark Class Extension

@interface FICDViewController () <UITableViewDataSource, UITableViewDelegate, FICDPhotosTableViewCellDelegate, FICDFullscreenPhotoDisplayControllerDelegate> {

    FICDTableView *_tableView;
    NSArray *_photos;
    
    NSString *_imageFormatName;
    NSArray *_imageFormatStyleToolbarItems;
    
    BOOL _usesImageTable;
    BOOL _shouldReloadTableViewAfterScrollingAnimationEnds;
    BOOL _shouldResetData;
    NSInteger _selectedMethodSegmentControlIndex;
    NSInteger _callbackCount;
    UILabel *_averageFPSLabel;
    UIStatusBarStyle statusBarStyle;
}

@end

#pragma mark

@implementation FICDViewController

#pragma mark - Object Lifecycle

- (id)init {
    self = [super init];
    return self;
}

- (void) checkImages {

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray *imageURLs = [mainBundle URLsForResourcesWithExtension:@"jpg" subdirectory:@"Demo Images"];
    
    if ([imageURLs count] > 0) {
        NSMutableArray *photos = [[NSMutableArray alloc] init];
        for (NSURL *imageURL in imageURLs) {
            FICDPhoto *photo = [[FICDPhoto alloc] init];
            [photo setSourceImageURL:imageURL];
            [photos addObject:photo];
        }
        
        while ([photos count] < 5000) {
            [photos addObjectsFromArray:photos]; // Create lots of photos to scroll through
        }
        
        _photos = photos;
    } else {
        NSString *title = @"No Source Images";
        NSString *message = @"There are no JPEG images in the Demo Images folder. Please run the fetch_demo_images.sh script, or add your own JPEG images to this folder before running the demo app.";

        UIAlertController* alert = [UIAlertController alertControllerWithTitle: title
                                                                       message: message
                                                                preferredStyle: UIAlertControllerStyleAlert];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle: @"OK"
                                                               style: UIAlertActionStyleCancel
                                                             handler: ^(__unused UIAlertAction* action) {
            //[NSThread exit];
        }];
        [alert addAction: cancelAction];

        // present alert
        UIViewController* topController = [UIApplication sharedApplication].delegate.window.rootViewController;
        [topController presentViewController: alert
                                        animated: YES
                                    completion: nil];
    }
}

- (void)dealloc {
    [_tableView setDelegate:nil];
    [_tableView setDataSource:nil];
}

#pragma mark - View Controller Lifecycle

- (void)loadView {
    CGRect viewFrame = [[UIScreen mainScreen] bounds];
    UIView *view = [[UIView alloc] initWithFrame:viewFrame];
    [view setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
    [view setBackgroundColor:[UIColor systemBackgroundColor]];

    [self setView:view];

    [self checkImages];

    // Configure the table view
    if (_tableView == nil) {
        _tableView = [[FICDTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        [_tableView setDataSource:self];
        [_tableView setDelegate:self];
        [_tableView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
        [_tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [_tableView registerClass:[FICDPhotosTableViewCell class] forCellReuseIdentifier:[FICDPhotosTableViewCell reuseIdentifier]];
        
        CGFloat tableViewCellOuterPadding = [FICDPhotosTableViewCell outerPadding];
        [_tableView setContentInset:UIEdgeInsetsMake(0, 0, tableViewCellOuterPadding, 0)];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [_tableView setScrollIndicatorInsets:UIEdgeInsetsMake(7, 0, 7, 1)];
        }
    }
    
    [_tableView setFrame:[view bounds]];
    [view addSubview:_tableView];
    
    // Configure the navigation item
    UINavigationItem *navigationItem = [self navigationItem];
    
    UIBarButtonItem *resetBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reset" style:UIBarButtonItemStylePlain target:self action:@selector(_reset)];
    [navigationItem setLeftBarButtonItem:resetBarButtonItem];
    
    UISegmentedControl *methodSegmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Conventional", @"Image Table", nil]];
    [methodSegmentedControl setSelectedSegmentIndex:0];
    [methodSegmentedControl addTarget:self action:@selector(_methodSegmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [methodSegmentedControl sizeToFit];
    [navigationItem setTitleView:methodSegmentedControl];
    
    // Configure the average FPS label
    if (_averageFPSLabel == nil) {
        _averageFPSLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 54, 22)];
        [_averageFPSLabel setBackgroundColor:[UIColor clearColor]];
        [_averageFPSLabel setFont:[UIFont boldSystemFontOfSize:16]];
        [_averageFPSLabel setTextAlignment:NSTextAlignmentRight];
        
        [_tableView addObserver:self forKeyPath:@"averageFPS" options:NSKeyValueObservingOptionNew context:NULL];
    }
    
    UIBarButtonItem *averageFPSLabelBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_averageFPSLabel];
    [navigationItem setRightBarButtonItem:averageFPSLabelBarButtonItem];
    
    // Configure the image format styles toolbar
    if (_imageFormatStyleToolbarItems == nil) {
        NSMutableArray *mutableImageFormatStyleToolbarItems = [NSMutableArray array];
        
        UIBarButtonItem *flexibleSpaceToolbarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
        [mutableImageFormatStyleToolbarItems addObject:flexibleSpaceToolbarItem];
        
        NSArray *imageFormatStyleSegmentedControlTitles = nil;
        BOOL userInterfaceIdiomIsPhone = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
        
        if (userInterfaceIdiomIsPhone) {
            imageFormatStyleSegmentedControlTitles = [NSArray arrayWithObjects:@"32BGRA", @"32BGR", @"16BGR", @"8Grayscale", nil];
        } else {
            imageFormatStyleSegmentedControlTitles = [NSArray arrayWithObjects:@"32-bit BGRA", @"32-bit BGR", @"16-bit BGR", @"8-bit Grayscale", nil];
        }
        
        UISegmentedControl *imageFormatStyleSegmentedControl = [[UISegmentedControl alloc] initWithItems:imageFormatStyleSegmentedControlTitles];
        [imageFormatStyleSegmentedControl setSelectedSegmentIndex:0];
        [imageFormatStyleSegmentedControl addTarget:self action:@selector(_imageFormatStyleSegmentedControlValueChanged:) forControlEvents:UIControlEventValueChanged];
        [imageFormatStyleSegmentedControl setApportionsSegmentWidthsByContent:userInterfaceIdiomIsPhone];
        [imageFormatStyleSegmentedControl sizeToFit];
        
        UIBarButtonItem *imageFormatStyleSegmentedControlToolbarItem = [[UIBarButtonItem alloc] initWithCustomView:imageFormatStyleSegmentedControl];
        [mutableImageFormatStyleToolbarItems addObject:imageFormatStyleSegmentedControlToolbarItem];
        
        [mutableImageFormatStyleToolbarItems addObject:flexibleSpaceToolbarItem];
        
        _imageFormatStyleToolbarItems = [mutableImageFormatStyleToolbarItems copy];
    }
    
    [self setToolbarItems:_imageFormatStyleToolbarItems];
    
    _imageFormatName = FICDPhotoSquareImage32BitBGRAFormatName;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[FICDFullscreenPhotoDisplayController sharedDisplayController] setDelegate:self];
    [self reloadTableViewAndScrollToTop:YES];
}

#pragma mark - Reloading Data

- (void)reloadTableViewAndScrollToTop:(BOOL)scrollToTop {
    //UIApplication *sharedApplication = [UIApplication sharedApplication];
    
    // Don't allow interaction events to interfere with thumbnail generation
    self.view.userInteractionEnabled = NO;

    if (scrollToTop) {
        // If the table view isn't already scrolled to top, we do that now, deferring the actual table view reloading logic until the animation finishes.
        CGFloat tableViewTopmostContentOffsetY = 0;
        CGFloat tableViewCurrentContentOffsetY = [_tableView contentOffset].y;
        
        if ([self respondsToSelector:@selector(topLayoutGuide)]) {
            id <UILayoutSupport> topLayoutGuide = [self topLayoutGuide];
            tableViewTopmostContentOffsetY = -[topLayoutGuide length];
        }
        
        if (tableViewCurrentContentOffsetY > tableViewTopmostContentOffsetY) {
            [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
            
            _shouldReloadTableViewAfterScrollingAnimationEnds = YES;
        }
    }
    
    if (_shouldReloadTableViewAfterScrollingAnimationEnds == NO) {
        // Reset the data now
        if (_shouldResetData) {
            _shouldResetData = NO;
            [[FICImageCache sharedImageCache] reset];
            
            // Delete all cached thumbnail images as well
            for (FICDPhoto *photo in _photos) {
                [photo deleteThumbnail];
            }
        }
        
        _usesImageTable = _selectedMethodSegmentControlIndex == 1;
        
        [[self navigationController] setToolbarHidden:(_usesImageTable == NO) animated:YES];
        
        dispatch_block_t tableViewReloadBlock = ^{
            [self->_tableView reloadData];
            [self->_tableView resetScrollingPerformanceCounters];
            
            if ([self->_tableView isHidden]) {
                [[self->_tableView layer] addAnimation:[CATransition animation] forKey:kCATransition];
            }
            
            [self->_tableView setHidden:NO];

            // Re-enable interaction events once every thumbnail has been generated
            self.view.userInteractionEnabled = YES;
        };
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // In order to make a fair comparison for both methods, we ensure that the cached data is ready to go before updating the UI.
            if (self->_usesImageTable) {
                self->_callbackCount = 0;
                NSSet *uniquePhotos = [NSSet setWithArray:self->_photos];
                for (FICDPhoto *photo in uniquePhotos) {
                    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
                    FICImageCache *sharedImageCache = [FICImageCache sharedImageCache];
                    
                    if ([sharedImageCache imageExistsForEntity:photo withFormatName:self->_imageFormatName] == NO) {
                        if (self->_callbackCount == 0) {
                            NSLog(@"*** FIC Demo: Fast Image Cache: Generating thumbnails...");
                            
                            // Hide the table view's contents while we generate new thumbnails
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self->_tableView setHidden:YES];
                                [[self->_tableView layer] addAnimation:[CATransition animation] forKey:kCATransition];
                            });
                        }
                        
                        self->_callbackCount++;
                        
                        [sharedImageCache asynchronouslyRetrieveImageForEntity:photo withFormatName:self->_imageFormatName completionBlock:^(id<FICEntity> entity, NSString *formatName, UIImage *image) {
                            self->_callbackCount--;
                            
                            if (self->_callbackCount == 0) {
                                NSLog(@"*** FIC Demo: Fast Image Cache: Generated thumbnails in %g seconds", CFAbsoluteTimeGetCurrent() - startTime);
                                dispatch_async(dispatch_get_main_queue(), tableViewReloadBlock);
                            }
                        }];
                    }
                }
                
                if (self->_callbackCount == 0) {
                    dispatch_async(dispatch_get_main_queue(), tableViewReloadBlock);
                }
            } else {
                [self _generateConventionalThumbnails];
                
                dispatch_async(dispatch_get_main_queue(), tableViewReloadBlock);
            }
        });
    }
}

- (void)_reset {
    _shouldResetData = YES;
    
    [self reloadTableViewAndScrollToTop:YES];
}

- (void)_methodSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    _selectedMethodSegmentControlIndex = [segmentedControl selectedSegmentIndex];
    
    // If there's any scrolling momentum, we want to stop it now
    CGPoint tableViewContentOffset = [_tableView contentOffset];
    [_tableView setContentOffset:tableViewContentOffset animated:NO];
    
    [self reloadTableViewAndScrollToTop:NO];
}

- (void)_imageFormatStyleSegmentedControlValueChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegmentedControlIndex = [segmentedControl selectedSegmentIndex];
    
    if (selectedSegmentedControlIndex == 0) {
        _imageFormatName = FICDPhotoSquareImage32BitBGRAFormatName;
    } else if (selectedSegmentedControlIndex == 1) {
        _imageFormatName = FICDPhotoSquareImage32BitBGRFormatName;
    } else if (selectedSegmentedControlIndex == 2) {
        _imageFormatName = FICDPhotoSquareImage16BitBGRFormatName;
    } else if (selectedSegmentedControlIndex == 3) {
        _imageFormatName = FICDPhotoSquareImage8BitGrayscaleFormatName;
    }
    
    [self reloadTableViewAndScrollToTop:NO];
}

#pragma mark - Image Helper Functions

static UIImage * _FICDColorAveragedImageFromImage(UIImage *image) {

    // Crop the image to the area occupied by the status bar
    CGSize imageSize = [image size];
    __block CGFloat statusBarHeight;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* vc = [UIApplication sharedApplication].delegate.window.rootViewController;
        statusBarHeight = vc.view.window.windowScene.statusBarManager.statusBarFrame.size.height;
    });

    CGRect cropRect = CGRectMake(0, 0, imageSize.width, statusBarHeight);
    
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
    UIImage *statusBarImage = [UIImage imageWithCGImage:croppedImageRef];
    CGImageRelease(croppedImageRef);
    
    // Draw the cropped image into a 1x1 bitmap context; this automatically averages the color values of every pixel
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGSize contextSize = CGSizeMake(1, 1);
    CGContextRef bitmapContextRef = CGBitmapContextCreate(NULL, contextSize.width, contextSize.height, 8, 0, colorSpaceRef, (kCGImageAlphaNoneSkipFirst & kCGBitmapAlphaInfoMask));
    CGContextSetInterpolationQuality(bitmapContextRef, kCGInterpolationMedium);
    
    CGRect drawRect = CGRectZero;
    drawRect.size = contextSize;
    
    UIGraphicsPushContext(bitmapContextRef);
    [statusBarImage drawInRect:drawRect];
    UIGraphicsPopContext();
    
    // Create an image from the bitmap context
    CGImageRef colorAveragedImageRef = CGBitmapContextCreateImage(bitmapContextRef);
    UIImage *colorAveragedImage = [UIImage imageWithCGImage:colorAveragedImageRef];
    
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(colorAveragedImageRef);
    CGContextRelease(bitmapContextRef);
    
    return colorAveragedImage;
}

static BOOL _FICDImageIsLight(UIImage *image) {
    BOOL imageIsLight = NO;
    
    CGImageRef imageRef = [image CGImage];
    CGDataProviderRef dataProviderRef = CGImageGetDataProvider(imageRef);
    NSData *pixelData = (__bridge_transfer NSData *)CGDataProviderCopyData(dataProviderRef);
    
    if ([pixelData length] > 0) {
        const UInt8 *pixelBytes = [pixelData bytes];
        
        // Whether or not the image format is opaque, the first byte is always the alpha component, followed by RGB.
        UInt8 pixelR = pixelBytes[1];
        UInt8 pixelG = pixelBytes[2];
        UInt8 pixelB = pixelBytes[3];
        
        // Calculate the perceived luminance of the pixel; the human eye favors green, followed by red, then blue.
        double perceivedLuminance = 1 - (((0.299 * pixelR) + (0.587 * pixelG) + (0.114 * pixelB)) / 255);
        imageIsLight = perceivedLuminance < 0.5;
    }
    
    return imageIsLight;
}

- (void)_updateStatusBarStyleForColorAveragedImage:(UIImage *)colorAveragedImage {
    BOOL imageIsLight = _FICDImageIsLight(colorAveragedImage);

    statusBarStyle = imageIsLight ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - Working with Thumbnails

- (void)_generateConventionalThumbnails {
    BOOL neededToGenerateThumbnail = NO;
    CFAbsoluteTime startTime = 0;
    
    NSSet *uniquePhotos = [NSSet setWithArray:_photos];
    for (FICDPhoto *photo in uniquePhotos) {
        if ([photo thumbnailImageExists] == NO) {
            if (neededToGenerateThumbnail == NO) {
                NSLog(@"*** FIC Demo: Conventional Method: Generating thumbnails...");
                startTime = CFAbsoluteTimeGetCurrent();
                
                neededToGenerateThumbnail = YES;
                
                // Hide the table view's contents while we generate new thumbnails
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_tableView setHidden:YES];
                    [[self->_tableView layer] addAnimation:[CATransition animation] forKey:kCATransition];
                });
            }
            
            @autoreleasepool {
                [photo generateThumbnail];
            }
        }
    }
    
    if (neededToGenerateThumbnail) {
        NSLog(@"*** FIC Demo: Conventional Method: Generated thumbnails in %g seconds", CFAbsoluteTimeGetCurrent() - startTime);
    }
}

#pragma mark - Displaying the Average Framerate

- (void)_displayAverageFPS:(CGFloat)averageFPS {
    if ([_averageFPSLabel attributedText] == nil) {
        CATransition *fadeTransition = [CATransition animation];
        [[_averageFPSLabel layer] addAnimation:fadeTransition forKey:kCATransition];
    }
    
    NSString *averageFPSString = [NSString stringWithFormat:@"%.0f", averageFPS];
    NSUInteger averageFPSStringLength = [averageFPSString length];
    NSString *displayString = [NSString stringWithFormat:@"%@ FPS", averageFPSString];
    
    UIColor *averageFPSColor = [UIColor blackColor];
    
    if (averageFPS > 45) {
        averageFPSColor = [UIColor colorWithHue:(114 / 359.0) saturation:0.99 brightness:0.89 alpha:1]; // Green
    } else if (averageFPS <= 45 && averageFPS > 30) {
        averageFPSColor = [UIColor colorWithHue:(38 / 359.0) saturation:0.99 brightness:0.89 alpha:1];  // Orange
    } else if (averageFPS < 30) {
        averageFPSColor = [UIColor colorWithHue:(6 / 359.0) saturation:0.99 brightness:0.89 alpha:1];   // Red
    }
    
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:displayString];
    [mutableAttributedString addAttribute:NSForegroundColorAttributeName value:averageFPSColor range:NSMakeRange(0, averageFPSStringLength)];
    
    [_averageFPSLabel setAttributedText:mutableAttributedString];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideAverageFPSLabel) object:nil];
    [self performSelector:@selector(_hideAverageFPSLabel) withObject:nil afterDelay:1.5];
}

- (void)_hideAverageFPSLabel {
    CATransition *fadeTransition = [CATransition animation];
    
    [_averageFPSLabel setAttributedText:nil];
    [[_averageFPSLabel layer] addAnimation:fadeTransition forKey:kCATransition];
}

#pragma mark - Protocol Implementations

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = ceilf((CGFloat)[_photos count] / (CGFloat)[FICDPhotosTableViewCell photosPerRow]);
    
    return numberOfRows;
}

- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    NSString *reuseIdentifier = [FICDPhotosTableViewCell reuseIdentifier];
    
    FICDPhotosTableViewCell *tableViewCell = (FICDPhotosTableViewCell *)[table dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    tableViewCell.selectionStyle = UITableViewCellSeparatorStyleNone;

    [tableViewCell setDelegate:self];
    [tableViewCell setImageFormatName:_imageFormatName];
    
    NSInteger photosPerRow = [FICDPhotosTableViewCell photosPerRow];
    NSInteger startIndex = [indexPath row] * photosPerRow;
    NSInteger count = MIN(photosPerRow, [_photos count] - startIndex);
    NSArray *photos = [_photos subarrayWithRange:NSMakeRange(startIndex, count)];
    
    [tableViewCell setUsesImageTable:_usesImageTable];
    [tableViewCell setPhotos:photos];
    
    return tableViewCell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [FICDPhotosTableViewCell rowHeight];
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate {
    if (willDecelerate == NO) {
        [_tableView resetScrollingPerformanceCounters];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [_tableView resetScrollingPerformanceCounters];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [_tableView resetScrollingPerformanceCounters];

    if (_shouldReloadTableViewAfterScrollingAnimationEnds) {
        _shouldReloadTableViewAfterScrollingAnimationEnds = NO;
        
        // Add a slight delay before reloading the data
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self reloadTableViewAndScrollToTop:NO];
        });
    }
}

#pragma mark - FICDPhotosTableViewCellDelegate

- (void)photosTableViewCell:(FICDPhotosTableViewCell *)photosTableViewCell didSelectPhoto:(FICDPhoto *)photo withImageView:(UIImageView *)imageView {
    [[FICDFullscreenPhotoDisplayController sharedDisplayController] showFullscreenPhoto:photo forImageFormatName:_imageFormatName withThumbnailImageView:imageView];
}

#pragma mark - FICDFullscreenPhotoDisplayControllerDelegate

- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController willShowSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView {
    // If we're running on iOS 7, we'll try to intelligently determine whether the photo contents underneath the status bar is light or dark.
    if ([self respondsToSelector:@selector(preferredStatusBarStyle)]) {
        if (_usesImageTable) {
            [[FICImageCache sharedImageCache] retrieveImageForEntity:photo withFormatName:FICDPhotoPixelImageFormatName completionBlock:^(id<FICEntity> entity, NSString *formatName, UIImage *image) {
                if (image != nil && [photoDisplayController isDisplayingPhoto]) {
                    [self _updateStatusBarStyleForColorAveragedImage:image];
                }
            }];
        } else {
            UIImage *colorAveragedImage = _FICDColorAveragedImageFromImage(sourceImage);
            [self _updateStatusBarStyleForColorAveragedImage:colorAveragedImage];
        }
    } else {
        statusBarStyle = UIStatusBarStyleLightContent;
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

- (UIStatusBarStyle) preferredStatusBarStyle {
    return statusBarStyle;
}

- (void)photoDisplayController:(FICDFullscreenPhotoDisplayController *)photoDisplayController willHideSourceImage:(UIImage *)sourceImage forPhoto:(FICDPhoto *)photo withThumbnailImageView:(UIImageView *)thumbnailImageView {
    statusBarStyle = UIStatusBarStyleDefault;
    [self setNeedsStatusBarAppearanceUpdate];
}

#pragma mark - NSObject (NSKeyValueObserving)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _tableView && [keyPath isEqualToString:@"averageFPS"]) {
        CGFloat averageFPS = [[change valueForKey:NSKeyValueChangeNewKey] floatValue];
        averageFPS = MIN(MAX(0, averageFPS), 60);
        [self _displayAverageFPS:averageFPS];
    }
}

@end
