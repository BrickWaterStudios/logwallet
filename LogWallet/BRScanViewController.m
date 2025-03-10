//
//  BRScanViewController.m
//  LogWallet
//
//  Created by Administrator on 7/15/14.
//  Copyright (c) 2014 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRScanViewController.h"
#import "BRPaymentRequest.h"
#import "NSString+Base58.h"

@interface BRScanViewController ()

@property (nonatomic, strong) IBOutlet UIView *cameraView;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;

@end

@implementation BRScanViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if (! device.hasTorch) self.toolbar.items = @[self.toolbar.items[0]];
    
    [self.toolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    [self.toolbar setShadowImage:[UIImage new] forToolbarPosition:UIToolbarPositionAny];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSError *error = nil;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];

    if (error) NSLog(@"%@", [error localizedDescription]);
    
    if ([device lockForConfiguration:&error]) {
        if (device.isAutoFocusRangeRestrictionSupported) {
            device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        }
        
        if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        
        [device unlockForConfiguration];
    }
    
    self.session = [AVCaptureSession new];
    if (input) [self.session addInput:input];
    [self.session addOutput:output];
    [output setMetadataObjectsDelegate:self.delegate queue:dispatch_get_main_queue()];

    if ([output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
        output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    }

    self.preview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.preview.frame = self.view.layer.bounds;
    [self.cameraView.layer addSublayer:self.preview];

    dispatch_async(dispatch_queue_create("qrscanner", NULL), ^{
        [self.session startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.session stopRunning];
    self.session = nil;
    [self.preview removeFromSuperlayer];
    self.preview = nil;

    [super viewDidDisappear:animated];
}

- (void)stop
{
    [self.session removeOutput:self.session.outputs.firstObject];
}

#pragma mark - IBAction

- (IBAction)flash:(id)sender
{
    NSError *error = nil;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if ([device lockForConfiguration:&error]) {
        device.torchMode = device.torchActive ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        [device unlockForConfiguration];
    }
}

- (IBAction)done:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

//#pragma mark - AVCaptureMetadataOutputObjectsDelegate
//
//- (void)resetQRGuide
//{
//    self.message.text = nil;
//    self.cameraGuide.image = [UIImage imageNamed:@"cameraguide"];
//}
//
//- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects
//fromConnection:(AVCaptureConnection *)connection
//{
//    for (AVMetadataMachineReadableCodeObject *o in metadataObjects) {
//        if (! [o.type isEqual:AVMetadataObjectTypeQRCode]) continue;
//
//        NSString *s = o.stringValue;
//        BRPaymentRequest *request = [BRPaymentRequest requestWithString:s];
//
//        if (! [request isValid] && ! [s isValidBitcoinPrivateKey] && ! [s isValidBitcoinBIP38Key]) {
//            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetQRGuide) object:nil];
//            self.cameraGuide.image = [UIImage imageNamed:@"cameraguide-red"];
//            self.message.text = [NSString stringWithFormat:@"%@\n%@",
//                                                NSLocalizedString(@"not a valid woodcoin address", nil),
//                                                request.paymentAddress];
//            [self performSelector:@selector(resetQRGuide) withObject:nil afterDelay:0.35];
//        }
//        else {
//            self.cameraGuide.image = [UIImage imageNamed:@"cameraguide-green"];
//            [self stop];
//
//            if (request.r.length > 0) { // start fetching payment protocol request right away
//                [BRPaymentRequest fetch:request.r timeout:5.0
//                completion:^(BRPaymentProtocolRequest *req, NSError *error) {
//                    if (error) request.r = nil;
//
//                    if (error && ! [request isValid]) {
//                        /*[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"couldn't make payment", nil)
//                          message:error.localizedDescription delegate:nil
//                          cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
//                        [self cancel:nil];*/
//                        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"couldn't make payment" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
//                        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil];
//                        [alert addAction:cancelAction];
//                        [self presentViewController:alert animated:YES completion:nil];
//                        return;
//                    }
//
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [self.navigationController dismissViewControllerAnimated:YES completion:^{
//                            if (error) {
////                                [self completeRequest:request];
//                                [self.presentingViewController confirmRequest:request];
//                            }
//                            else [self.navigationController.presentingViewController confirmProtocolRequest:req];
//
//                            [self resetQRGuide];
//                        }];
//                    });
//                }];
//            }
//            else {
//                [self.navigationController dismissViewControllerAnimated:YES completion:^{
//                    [self completeRequest:request];
//                    [self resetQRGuide];
//                }];
//            }
//        }
//
//        break;
//    }
//}

@end
