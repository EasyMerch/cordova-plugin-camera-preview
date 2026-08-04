#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import <GLKit/GLKit.h>
#import "CameraPreview.h"
#import "encode.h"
#import <Accelerate/Accelerate.h>

#define TMP_IMAGE_PREFIX @"cpcp_capture_"

@implementation CameraPreview

-(void) pluginInitialize{
  // start as transparent
  self.webView.opaque = NO;
  self.webView.backgroundColor = [UIColor clearColor];
}

- (void) startCamera:(CDVInvokedUrlCommand*)command {

  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
  }

  if (command.arguments.count > 3) {
  CGRect rect = CGRectMake(
    (CGFloat)[command.arguments[0] floatValue],
    (CGFloat)[command.arguments[1] floatValue],
    (CGFloat)[command.arguments[2] floatValue],
    (CGFloat)[command.arguments[3] floatValue]
  );
    NSString *defaultCamera = command.arguments[4];
    BOOL tapToTakePicture = (BOOL)[command.arguments[5] boolValue];
    BOOL dragEnabled = (BOOL)[command.arguments[6] boolValue];
    BOOL toBack = (BOOL)[command.arguments[7] boolValue];
    CGFloat alpha = (CGFloat)[command.arguments[8] floatValue];
    BOOL tapToFocus = (BOOL) [command.arguments[9] boolValue];
    BOOL disableExifHeaderStripping = (BOOL) [command.arguments[10] boolValue]; // ignore Android only
    self.storeToFile = (BOOL) [command.arguments[11] boolValue];
    self.disableShutterSound = (BOOL) [command.arguments[12] boolValue]; // ignore Android only
    self.enableFastShoot = (BOOL) [command.arguments[13] boolValue];

    // Create the session manager
    self.sessionManager = [[CameraSessionManager alloc] init];

    // render controller setup
    self.cameraRenderController = [[CameraRenderController alloc] init];
    self.cameraRenderController.dragEnabled = dragEnabled;
    self.cameraRenderController.tapToTakePicture = tapToTakePicture;
    self.cameraRenderController.tapToFocus = tapToFocus;
    self.cameraRenderController.sessionManager = self.sessionManager;
  [self setPreviewRect:rect];
    self.cameraRenderController.delegate = self;

    [self.viewController addChildViewController:self.cameraRenderController];

    if (toBack) {
      // display the camera below the webview

      // make transparent
      self.webView.opaque = NO;
      self.webView.backgroundColor = [UIColor clearColor];

      self.webView.scrollView.opaque = NO;
      self.webView.scrollView.backgroundColor = [UIColor clearColor];

      [self.viewController.view insertSubview:self.cameraRenderController.view atIndex:0];
      [self.webView.superview bringSubviewToFront:self.webView];
    } else {
      self.cameraRenderController.view.alpha = alpha;
      [self.webView.superview insertSubview:self.cameraRenderController.view aboveSubview:self.webView];
    }

    // Setup session
    self.sessionManager.delegate = self.cameraRenderController;

    [self.sessionManager setupSession:defaultCamera completion:^(BOOL started, AVCaptureDevice *camera) {

      NSDictionary *cameraInfo = @{
        @"modelID": camera.modelID,
        @"deviceType": camera.deviceType,
        @"position": @(camera.position),
        @"zoomRange": @{
          @"min": @(camera.minAvailableVideoZoomFactor),
          @"max": @(camera.activeFormat.videoMaxZoomFactor),
        }
      };

      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:cameraInfo] callbackId:command.callbackId];

    }];

  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

- (void) setPreviewRect:(CGRect)rect {
  CGFloat x = rect.origin.x + self.webView.frame.origin.x;
  CGFloat y = rect.origin.y + self.webView.frame.origin.y;
  self.cameraRenderController.view.frame = CGRectMake(x, y, rect.size.width, rect.size.height);
}

- (void) stopCamera:(CDVInvokedUrlCommand*)command {
    NSLog(@"stopCamera");
    CDVPluginResult *pluginResult;

    if(self.sessionManager != nil) {
        [self.cameraRenderController.view removeFromSuperview];
        [self.cameraRenderController removeFromParentViewController];

        self.cameraRenderController = nil;
        self.sessionManager = nil;

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) hideCamera:(CDVInvokedUrlCommand*)command {
  NSLog(@"hideCamera");
  CDVPluginResult *pluginResult;

  if (self.cameraRenderController != nil) {
    [self.cameraRenderController.view setHidden:YES];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) showCamera:(CDVInvokedUrlCommand*)command {
  NSLog(@"showCamera");
  CDVPluginResult *pluginResult;

  if (self.cameraRenderController != nil) {
    [self.cameraRenderController.view setHidden:NO];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) switchCamera:(CDVInvokedUrlCommand*)command {
  NSLog(@"switchCamera");
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    [self.sessionManager switchCamera:^(BOOL switched) {

      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];

    }];

  } else {

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

- (void) getSupportedFocusModes:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSArray * focusModes = [self.sessionManager getFocusModes];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:focusModes];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFocusMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSString * focusMode = [self.sessionManager getFocusMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFocusMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  NSString * focusMode = [command.arguments objectAtIndex:0];
  if (self.sessionManager != nil) {
    [self.sessionManager setFocusMode:focusMode];
    NSString * focusMode = [self.sessionManager getFocusMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:focusMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedFlashModes:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSArray * flashModes = [self.sessionManager getFlashModes];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:flashModes];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getFlashMode:(CDVInvokedUrlCommand*)command {

  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    BOOL isTorchActive = [self.sessionManager isTorchActive];
    NSInteger flashMode = [self.sessionManager getFlashMode];
    NSString * sFlashMode;
    if (isTorchActive) {
      sFlashMode = @"torch";
    } else {
      if (flashMode == 0) {
        sFlashMode = @"off";
      } else if (flashMode == 1) {
        sFlashMode = @"on";
      } else if (flashMode == 2) {
        sFlashMode = @"auto";
      } else {
        sFlashMode = @"unsupported";
      }
    }
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:sFlashMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setFlashMode:(CDVInvokedUrlCommand*)command {
  NSLog(@"Flash Mode");
  NSString *errMsg;
  CDVPluginResult *pluginResult;

  NSString *flashMode = [command.arguments objectAtIndex:0];

  if (self.sessionManager != nil) {
    if ([flashMode isEqual: @"off"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeOff];
    } else if ([flashMode isEqual: @"on"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeOn];
    } else if ([flashMode isEqual: @"auto"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeAuto];
    } else if ([flashMode isEqual: @"torch"]) {
      [self.sessionManager setTorchMode];
    } else {
      errMsg = @"Flash Mode not supported";
    }
  } else {
    errMsg = @"Session not started";
  }

  if (errMsg) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setZoom:(CDVInvokedUrlCommand*)command {
  NSLog(@"Zoom");
  CDVPluginResult *pluginResult;

  CGFloat desiredZoomFactor = [[command.arguments objectAtIndex:0] floatValue];

  if (self.sessionManager != nil) {
    [self.sessionManager setZoom:desiredZoomFactor];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getZoom:(CDVInvokedUrlCommand*)command {

  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    CGFloat zoom = [self.sessionManager getZoom];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:zoom ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getHorizontalFOV:(CDVInvokedUrlCommand*)command {

  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    float fov = [self.sessionManager getHorizontalFOV];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:fov ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getMaxZoom:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    CGFloat maxZoom = [self.sessionManager getMaxZoom];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:maxZoom ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureModes:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSArray * exposureModes = [self.sessionManager getExposureModes];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:exposureModes];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSString * exposureMode = [self.sessionManager getExposureMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  NSString * exposureMode = [command.arguments objectAtIndex:0];
  if (self.sessionManager != nil) {
    [self.sessionManager setExposureMode:exposureMode];
    NSString * exposureMode = [self.sessionManager getExposureMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:exposureMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedWhiteBalanceModes:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSArray * whiteBalanceModes = [self.sessionManager getSupportedWhiteBalanceModes];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:whiteBalanceModes ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSString * whiteBalanceMode = [self.sessionManager getWhiteBalanceMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:whiteBalanceMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setWhiteBalanceMode:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  NSString * whiteBalanceMode = [command.arguments objectAtIndex:0];
  if (self.sessionManager != nil) {
    [self.sessionManager setWhiteBalanceMode:whiteBalanceMode];
    NSString * wbMode = [self.sessionManager getWhiteBalanceMode];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:wbMode ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensationRange:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    NSArray * exposureRange = [self.sessionManager getExposureCompensationRange];
    NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
    [dimensions setValue:exposureRange[0] forKey:@"min"];
    [dimensions setValue:exposureRange[1] forKey:@"max"];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dimensions];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getExposureCompensation:(CDVInvokedUrlCommand*)command {
  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    CGFloat exposureCompensation = [self.sessionManager getExposureCompensation];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation ];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setExposureCompensation:(CDVInvokedUrlCommand*)command {
  NSLog(@"Zoom");
  CDVPluginResult *pluginResult;

  CGFloat exposureCompensation = [[command.arguments objectAtIndex:0] floatValue];

  if (self.sessionManager != nil) {
    [self.sessionManager setExposureCompensation:exposureCompensation];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:exposureCompensation];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) takePicture:(CDVInvokedUrlCommand*)command {
  NSLog(@"takePicture");
  CDVPluginResult *pluginResult;

  if (self.cameraRenderController != NULL) {
    self.onPictureTakenHandlerId = command.callbackId;

    CGFloat width = (CGFloat)[command.arguments[0] floatValue];
    CGFloat height = (CGFloat)[command.arguments[1] floatValue];
    CGFloat quality = (CGFloat)[command.arguments[2] floatValue] / 100.0f;
    CGFloat losslessPreset = (CGFloat)[command.arguments[3] floatValue];
    NSString* format = (NSString*)[command.arguments[4] stringValue] ?: @"jpeg";

    [self invokeTakePicture:width withHeight:height withQuality:quality withLossLessPreset:losslessPreset withFormat:format];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

- (void) takeSnapshot:(CDVInvokedUrlCommand*)command {
    NSLog(@"takeSnapshot");
    CDVPluginResult *pluginResult;
    if (self.cameraRenderController != NULL && self.cameraRenderController.view != NULL) {
        CGFloat quality = (CGFloat)[command.arguments[0] floatValue] / 100.0f;
        dispatch_async(self.sessionManager.sessionQueue, ^{
            UIImage *image = ((GLKView*)self.cameraRenderController.view).snapshot;
            NSString *base64Image = [self getBase64Image:image.CGImage withQuality:quality];
            NSMutableArray *params = [[NSMutableArray alloc] init];
            [params addObject:base64Image];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
            [pluginResult setKeepCallbackAsBool:false];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}


-(void) setColorEffect:(CDVInvokedUrlCommand*)command {
  NSLog(@"setColorEffect");
  CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  NSString *filterName = command.arguments[0];

  if(self.sessionManager != nil){
    if ([filterName isEqual: @"none"]) {
      dispatch_async(self.sessionManager.sessionQueue, ^{
          [self.sessionManager setCiFilter:nil];
          });
    } else if ([filterName isEqual: @"mono"]) {
      dispatch_async(self.sessionManager.sessionQueue, ^{
          CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"];
          [filter setDefaults];
          [self.sessionManager setCiFilter:filter];
          });
    } else if ([filterName isEqual: @"negative"]) {
      dispatch_async(self.sessionManager.sessionQueue, ^{
          CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
          [filter setDefaults];
          [self.sessionManager setCiFilter:filter];
          });
    } else if ([filterName isEqual: @"posterize"]) {
      dispatch_async(self.sessionManager.sessionQueue, ^{
          CIFilter *filter = [CIFilter filterWithName:@"CIColorPosterize"];
          [filter setDefaults];
          [self.sessionManager setCiFilter:filter];
          });
    } else if ([filterName isEqual: @"sepia"]) {
      dispatch_async(self.sessionManager.sessionQueue, ^{
          CIFilter *filter = [CIFilter filterWithName:@"CISepiaTone"];
          [filter setDefaults];
          [self.sessionManager setCiFilter:filter];
          });
    } else {
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Filter not found"];
    }
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) setPreviewSize: (CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 1) {
    CGFloat x = 0, y = 0;
    if(command.arguments.count > 2){
      x = (CGFloat)[command.arguments[2] floatValue];
      y = (CGFloat)[command.arguments[3] floatValue];
    }
    CGRect rect = CGRectMake(
      x,
      y,
      (CGFloat)[command.arguments[0] floatValue],
      (CGFloat)[command.arguments[1] floatValue]
    );
    [self setPreviewRect:rect];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command {
  NSLog(@"getSupportedPictureSizes");
  CDVPluginResult *pluginResult;

  if(self.sessionManager != nil){
    NSArray *formats = self.sessionManager.getDeviceFormats;
    NSMutableArray *jsonFormats = [NSMutableArray new];
    int lastWidth = 0;
    int lastHeight = 0;
    for (AVCaptureDeviceFormat *format in formats) {
      CMVideoDimensions dim = format.highResolutionStillImageDimensions;
      if (dim.width!=lastWidth && dim.height != lastHeight) {
        NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
        NSNumber *width = [NSNumber numberWithInt:dim.width];
        NSNumber *height = [NSNumber numberWithInt:dim.height];
        [dimensions setValue:width forKey:@"width"];
        [dimensions setValue:height forKey:@"height"];
        [jsonFormats addObject:dimensions];
        lastWidth = dim.width;
        lastHeight = dim.height;
      }
    }
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:jsonFormats];

  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSString *)getBase64Image:(CGImageRef)imageRef withQuality:(CGFloat) quality {
  NSString *base64Image = nil;

  @try {
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    NSData *imageData = UIImageJPEGRepresentation(image, quality);
    base64Image = [imageData base64EncodedStringWithOptions:0];
  }
  @catch (NSException *exception) {
    NSLog(@"error while get base64Image: %@", [exception reason]);
  }

  return base64Image;
}

- (void) tapToFocus:(CDVInvokedUrlCommand*)command {
  NSLog(@"tapToFocus");
  CDVPluginResult *pluginResult;

  CGFloat xPoint = [[command.arguments objectAtIndex:0] floatValue];
  CGFloat yPoint = [[command.arguments objectAtIndex:1] floatValue];

  if (self.sessionManager != nil) {
    [self.sessionManager tapToFocus:xPoint yPoint:yPoint];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (double)radiansFromUIImageOrientation:(UIImageOrientation)orientation {
  double radians;

  switch ([[UIApplication sharedApplication] statusBarOrientation]) {
    case UIDeviceOrientationPortrait:
      radians = M_PI_2;
      break;
    case UIDeviceOrientationLandscapeLeft:
      radians = 0.f;
      break;
    case UIDeviceOrientationLandscapeRight:
      radians = M_PI;
      break;
    case UIDeviceOrientationPortraitUpsideDown:
      radians = -M_PI_2;
      break;
  }

  return radians;
}

-(CGImageRef) CGImageRotated:(CGImageRef) originalCGImage withRadians:(double) radians {
  CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
  CGSize rotatedSize;
  if (radians == M_PI_2 || radians == -M_PI_2) {
    rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
  } else {
    rotatedSize = imageSize;
  }

  double rotatedCenterX = rotatedSize.width / 2.f;
  double rotatedCenterY = rotatedSize.height / 2.f;

  UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
  CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
  if (radians == 0.f || radians == M_PI) { // 0 or 180 degrees
    CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
    if (radians == 0.0f) {
      CGContextScaleCTM(rotatedContext, 1.f, -1.f);
    } else {
      CGContextScaleCTM(rotatedContext, -1.f, 1.f);
    }
    CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
  } else if (radians == M_PI_2 || radians == -M_PI_2) { // +/- 90 degrees
    CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
    CGContextRotateCTM(rotatedContext, radians);
    CGContextScaleCTM(rotatedContext, 1.f, -1.f);
    CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
  }

  CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
  CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
  CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);

  UIGraphicsEndImageContext();

  return rotatedCGImage;
}

- (void) invokeTapToFocus:(CGPoint)point {
  [self.sessionManager tapToFocus:point.x yPoint:point.y];
}

- (void) invokeTakePicture {
	[self invokeTakePicture:0.0 withHeight:0.0 withQuality:0.85 withLossLessPreset:0.0 withFormat:@"jpeg"];
}

- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality {
	[self invokeTakePicture:width withHeight:height withQuality:quality withLossLessPreset:0.0 withFormat:@"jpeg"];
}

- (void) invokeTakePicture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality withLossLessPreset:(CGFloat) lossLessPreset withFormat:(NSString *) format {
    self.takePictureWidth = width;
    self.takePictureHeight = height;
    self.takePictureQuality = quality;
    self.takePictureLosslessPreset = lossLessPreset;
    self.imageFormat = format;
    AVCapturePhotoSettings* settings = [self.sessionManager captureSettingsWithFormat:format];
    [self.sessionManager.stillImageOutput capturePhotoWithSettings:settings delegate:self];
}

- (void) invokeTakePictureOnFocus {
    // the sessionManager will call onFocus, as soon as the camera is done with focussing.
  [self.sessionManager takePictureOnFocus];
}

- (NSData *)processImageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer targetWidth:(int)targetWidth targetHeight:(int)targetHeight orientation:(CGImagePropertyOrientation)orientation wrapX:(BOOL)wrapX quality:(float)quality losslessPreset:(float)losslessPreset {
    WebPPicture pic;
    WebPPictureInit(&pic);
    pic.use_argb = 1;
    uint8_t *imageData = NULL;
    int stride;
    int w, h;
    if (pixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        uint8_t *baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer);
        w = (int)CVPixelBufferGetWidth(pixelBuffer);
        h = (int)CVPixelBufferGetHeight(pixelBuffer);
        stride = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
        
        imageData = malloc(h * stride);
        for (int y = 0; y < h; y++) {
            memcpy(imageData + y * stride, baseAddr + y * stride, stride);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    } else {
        return nil;
    }
    
    pic.width = w;
    pic.height = h;
    
    if (!WebPPictureImportBGRA(&pic, imageData, stride)) {
        free(imageData);
        WebPPictureFree(&pic);
        return nil;
    }
    
    if (targetWidth > 0 && targetHeight > 0) {
        if (!WebPPictureRescale(&pic, targetWidth, targetHeight)) {
            WebPPictureFree(&pic);
            return nil;
        }
    }
    
    if (imageData) {
        vImage_Buffer src = { imageData, (vImagePixelCount)h, (vImagePixelCount)w, stride };
        uint8_t *mirrored_data = malloc(h * stride);
        vImage_Buffer dst = { mirrored_data, (vImagePixelCount)h, (vImagePixelCount)w, stride };
        vImage_Error err = kvImageNoError;
        BOOL mirrored = true;
        switch (orientation) {
            case kCGImagePropertyOrientationUpMirrored:
                err = vImageHorizontalReflect_ARGB8888(&src, &dst, kvImageNoFlags);
                break;
            case kCGImagePropertyOrientationLeftMirrored:
            case kCGImagePropertyOrientationRightMirrored:
            case kCGImagePropertyOrientationDownMirrored:
                err = vImageVerticalReflect_ARGB8888(&src, &dst, kvImageNoFlags);
                break;
            default:
                free(mirrored_data);
                mirrored = false;
                break;
        }
        if (mirrored) {
            free(imageData);
            if (err != kvImageNoError) {
                free(mirrored_data);
                WebPPictureFree(&pic);
                return nil;
            }
            
            if (!mirrored_data) {
                WebPPictureFree(&pic);
                return nil;
            }
            
            imageData = mirrored_data;
        }
        
        if (wrapX) {
            uint8_t *wrap_data = malloc(h * stride);
            src = (vImage_Buffer){ imageData, (vImagePixelCount)h, (vImagePixelCount)w, w * 4 };
            dst = (vImage_Buffer){ wrap_data, (vImagePixelCount)h, (vImagePixelCount)w, w * 4 };
            err = vImageVerticalReflect_ARGB8888(&src, &dst, kvImageNoFlags);
            free(imageData);
            if (err != kvImageNoError) {
                free(wrap_data);
                WebPPictureFree(&pic);
                return  nil;
            }
            
            if (!wrap_data) {
                WebPPictureFree(&pic);
                return nil;
            }
            imageData = wrap_data;
        }
        
        src = (vImage_Buffer){ imageData, (vImagePixelCount)h, (vImagePixelCount)w, w * 4 };
        uint8_t *rotatedData = malloc(h * stride);
        uint8_t bgColor[4] = {0, 0, 0, 0};
        int newW;
        int newH;
        
        switch (orientation) {
            case kCGImagePropertyOrientationDownMirrored:
            case kCGImagePropertyOrientationUp:
            case kCGImagePropertyOrientationUpMirrored:
                newW = w;
                newH = h;
                dst = (vImage_Buffer){ rotatedData, newH, newW, newW * 4 };
                err = vImageRotate90_ARGB8888(&src, &dst, 0, bgColor, kvImageNoFlags);
                break;
            case kCGImagePropertyOrientationDown:
                newW = w;
                newH = h;
                dst = (vImage_Buffer){ rotatedData, newH, newW, newW * 4 };
                err = vImageRotate90_ARGB8888(&src, &dst, 2, bgColor, kvImageNoFlags);
                break;
            case kCGImagePropertyOrientationLeft:
            case kCGImagePropertyOrientationLeftMirrored:
                newW = h;
                newH = w;
                dst = (vImage_Buffer){ rotatedData, newH, newW, newW * 4 };
                err = vImageRotate90_ARGB8888(&src, &dst, 1, bgColor, kvImageNoFlags);
                break;
            case kCGImagePropertyOrientationRightMirrored:
            case kCGImagePropertyOrientationRight:
                newW = h;
                newH = w;
                dst = (vImage_Buffer){ rotatedData, newH, newW, newW * 4 };
                err = vImageRotate90_ARGB8888(&src, &dst, 3, bgColor, kvImageNoFlags);
                break;
            default:
                break;
        }

        free(imageData);
        if (err != kvImageNoError) {
            free(rotatedData);
            WebPPictureFree(&pic);
            return nil;
        }

        imageData = rotatedData;
        w = newW;
        h = newH;
    }
    
    WebPPictureFree(&pic);
    WebPPictureInit(&pic);
    pic.width = w;
    pic.height = h;
    
    if (!WebPPictureImportBGRA(&pic, imageData, w * 4)) {
        free(imageData);
        WebPPictureFree(&pic);
        return nil;
    }
    
    WebPConfig config;
    if (!WebPConfigInit(&config)) {
        NSLog(@"WebPConfigInit failed");
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return nil;
    }
    
    if (!WebPConfigLosslessPreset(&config, losslessPreset)) {
        NSLog(@"WebPConfigLosslessPreset failed");
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return nil;
    }
    config.quality = quality;
    
    NSData *outputData = nil;
    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    pic.writer = WebPMemoryWrite;
    pic.custom_ptr = &writer;
    uint8_t *webpData = NULL;
    size_t webpSize = 0;
    
    if (WebPEncode(&config, &pic)) {
        webpData = writer.mem;
        webpSize = writer.size;
        outputData = [NSData dataWithBytes:webpData length:webpSize];
    } else {
        WebPMemoryWriterClear(&writer);
        NSLog(@"WebPEncode failed");
    }
    WebPMemoryWriterClear(&writer);
    
    WebPPictureFree(&pic);
    return outputData;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    CGFloat width = self.takePictureWidth;
    CGFloat height = self.takePictureHeight;
    CGFloat quality = self.takePictureQuality;
    CGFloat losslessPreset = self.takePictureLosslessPreset ?: 0;
    NSString *format = self.imageFormat ?: @"jpeg";
    BOOL enableFastShoot = [format isEqualToString:@"jpeg"] && self.enableFastShoot;

    if (error) {
        NSLog(@"%@", error);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error description]];
        [pluginResult setKeepCallbackAsBool:self.cameraRenderController.tapToTakePicture];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
    } else {
        CIImage *capturedCImage;
        CGSize imageSize;
        NSData *webpDataObj = NULL;
        if ([format isEqualToString:@"webp"]) {
            NSDictionary *metadata = photo.metadata;
            NSNumber *orientationNumber = metadata[(NSString *)kCGImagePropertyOrientation] ?: 0;
            CGImagePropertyOrientation orientation = [orientationNumber intValue];
            CVPixelBufferRef pixelBuffer = photo.pixelBuffer;
            if (pixelBuffer) {
                BOOL wrapX = self.sessionManager.defaultCamera == AVCaptureDevicePositionFront;
                webpDataObj = [self processImageFromPixelBuffer:pixelBuffer targetWidth:width targetHeight:height orientation: orientation wrapX: wrapX quality:quality losslessPreset:losslessPreset];
            }
        } else {
            NSData *imageData = [photo fileDataRepresentation];
            if (enableFastShoot) {
                NSDictionary *ciImageOptions = @{
                    kCIImageApplyOrientationProperty : @true
                };
                capturedCImage = [[CIImage alloc] initWithData:imageData options:ciImageOptions];
                imageSize = capturedCImage.extent.size;
            } else {
                UIImage *capturedImage = [[UIImage alloc] initWithData:imageData];
                capturedCImage = [[CIImage alloc] initWithCGImage:[capturedImage CGImage]];
                imageSize = capturedImage.size;
            }
        }

        if(width > 0 && height > 0){
            CGFloat scaleHeight = width/imageSize.height;
            CGFloat scaleWidth = height/imageSize.width;
            CGFloat scale = scaleHeight > scaleWidth ? scaleWidth : scaleHeight;

            CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
            [resizeFilter setValue:capturedCImage forKey:kCIInputImageKey];
            [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
            [resizeFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
            capturedCImage = [resizeFilter outputImage];
        }

        CIImage *imageToFilter;
        CIImage *finalCImage;

        //fix front mirroring
        if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
            CGAffineTransform matrix;
            if(enableFastShoot){
                matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(-1, 1), capturedCImage.extent.size.width, 0);
            } else {
                matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, capturedCImage.extent.size.height);
            }
            imageToFilter = [capturedCImage imageByApplyingTransform:matrix];
        } else {
            imageToFilter = capturedCImage;
        }

        CIFilter *filter = [self.sessionManager ciFilter];
        if (filter != nil) {
            [self.sessionManager.filterLock lock];
            [filter setValue:imageToFilter forKey:kCIInputImageKey];
            finalCImage = [filter outputImage];
            [self.sessionManager.filterLock unlock];
        } else {
            finalCImage = imageToFilter;
        }

        CDVPluginResult *pluginResult = nil;
        
        if ([format isEqualToString:@"webp"]) {
            if (!webpDataObj) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:@"WebP encoding failed"];
            } else if (self.storeToFile) {
                NSString *filePath = [self getTempFilePath:@"webp"];
                NSError *writeError = nil;
                if (![webpDataObj writeToFile:filePath options:NSAtomicWrite error:&writeError]) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:writeError.localizedDescription];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSURL fileURLWithPath:filePath].absoluteString];
                }
            } else {
                NSString *base64 = [webpDataObj base64EncodedStringWithOptions:0];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[base64]];
            }
        } else if (enableFastShoot) {
            if (self.storeToFile) {
                NSString *filePath = [self getTempFilePath:@"jpg"];
                NSURL *path = [NSURL fileURLWithPath:filePath];
                CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                NSDictionary *options = @{
                    (NSString *)kCGImageDestinationLossyCompressionQuality : [NSNumber numberWithFloat:quality]
                };
                NSError *error;
                BOOL saved = [self.cameraRenderController.ciContext writeJPEGRepresentationOfImage:finalCImage toURL:path colorSpace:colorSpace options:options error:&error];
                if (!saved) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[error localizedDescription]];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[path absoluteString]];
                }
            } else {
                CGImageRef finalCGImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
                UIImage *resultImage = [UIImage imageWithCGImage:finalCGImage];
                double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
                CGImageRef rotatedCGImage = [self CGImageRotated:finalCGImage withRadians:radians];
                CGImageRelease(finalCGImage);
                if (!rotatedCGImage) {
                    rotatedCGImage = finalCGImage;
                }
                NSData *jpegData = UIImageJPEGRepresentation([UIImage imageWithCGImage:rotatedCGImage], quality);
                CGImageRelease(rotatedCGImage);
                if (!jpegData) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"JPEG encoding failed"];
                } else {
                    NSString *base64 = [jpegData base64EncodedStringWithOptions:0];
                    NSMutableArray *params = [[NSMutableArray alloc] init];
                    [params addObject:base64];
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
                }
            }
        } else {
            CGImageRef finalCGImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
            if (!finalCGImage) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to create CGImage"];
                [pluginResult setKeepCallbackAsBool:self.cameraRenderController.tapToTakePicture];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
                return;
            }

            UIImage *resultImage = [UIImage imageWithCGImage:finalCGImage];
            double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
            CGImageRef rotatedCGImage = [self CGImageRotated:finalCGImage withRadians:radians];
            CGImageRelease(finalCGImage);
            if (!rotatedCGImage) {
                rotatedCGImage = finalCGImage;
            }

            NSData *outputData = nil;
            NSString *fileExtension = @"jpg";
            outputData = UIImageJPEGRepresentation([UIImage imageWithCGImage:rotatedCGImage], quality);

            CGImageRelease(rotatedCGImage);

            if (!outputData) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to encode image"];
                [pluginResult setKeepCallbackAsBool:self.cameraRenderController.tapToTakePicture];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
                return;
            }

            if (self.storeToFile) {
                NSString *filePath = [self getTempFilePath:fileExtension];
                NSError *writeError = nil;
                BOOL saved = [outputData writeToFile:filePath options:NSAtomicWrite error:&writeError];
                if (!saved) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[writeError localizedDescription]];
                } else {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[[NSURL fileURLWithPath:filePath] absoluteString]];
                }
            } else {
                NSString *base64 = [outputData base64EncodedStringWithOptions:0];
                NSMutableArray *params = [[NSMutableArray alloc] init];
                [params addObject:base64];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:params];
            }
        }

        [pluginResult setKeepCallbackAsBool:self.cameraRenderController.tapToTakePicture];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
    }
}

- (NSData *)webpDataFromCIImage:(CIImage *)ciImage
                        quality:(float)quality
                      ciContext:(CIContext *)ciContext {
    CGRect extent = ciImage.extent;
    size_t width = (size_t)extent.size.width;
    size_t height = (size_t)extent.size.height;
    if (width == 0 || height == 0) return nil;
    
    int webpQuality = (int)(quality * 100);
    webpQuality = MAX(0, MIN(100, webpQuality));

    size_t bytesPerRow = width * 4;
    uint8_t *rgba = (uint8_t *)malloc(bytesPerRow * height);
    if (!rgba) return nil;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    [ciContext render:ciImage
             toBitmap:rgba
             rowBytes:bytesPerRow
               bounds:extent
               format:kCIFormatRGBA8
           colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);

    WebPConfig config;
    if (!WebPConfigPreset(&config, WEBP_PRESET_PICTURE, webpQuality)) {
        free(rgba);
        return nil;
    }
    config.method = 6;

    WebPPicture picture;
    if (!WebPPictureInit(&picture)) {
        free(rgba);
        return nil;
    }
    picture.width = (int)width;
    picture.height = (int)height;
    picture.use_argb = 1;

    if (!WebPPictureImportRGBA(&picture, rgba, (int)bytesPerRow)) {
        WebPPictureFree(&picture);
        free(rgba);
        return nil;
    }

    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    picture.writer = WebPMemoryWrite;
    picture.custom_ptr = &writer;

    if (!WebPEncode(&config, &picture)) {
        WebPMemoryWriterClear(&writer);
        WebPPictureFree(&picture);
        free(rgba);
        return nil;
    }

    NSData *webpData = [NSData dataWithBytes:writer.mem length:writer.size];

    WebPMemoryWriterClear(&writer);
    WebPPictureFree(&picture);
    free(rgba);

    return webpData;
}

- (NSString*)getTempDirectoryPath
{
  NSString* tmpPath = [NSTemporaryDirectory()stringByStandardizingPath];
  return tmpPath;
}

- (NSString*)getTempFilePath:(NSString*)extension
{
    NSString* tmpPath = [self getTempDirectoryPath];
    NSFileManager* fileMgr = [[NSFileManager alloc] init]; // recommended by Apple (vs [NSFileManager defaultManager]) to be threadsafe
    NSString* filePath;

    // generate unique file name
    int i = 1;
    do {
        filePath = [NSString stringWithFormat:@"%@/%@%04d.%@", tmpPath, TMP_IMAGE_PREFIX, i++, extension];
    } while ([fileMgr fileExistsAtPath:filePath]);

    return filePath;
}

@end
