//
//  QRCodeViewController.m
//  qtum wallet
//
//  Created by Sharaev Vladimir on 21.11.16.
//  Copyright © 2016 Designsters. All rights reserved.
//

#import "QRCodeViewController.h"
#import <MTBBarcodeScanner.h>

@interface QRCodeViewController ()

@property (nonatomic, strong) MTBBarcodeScanner *scanner;
@property (nonatomic, copy) void (^scanningCompletion)(NSArray *codes);

@property (weak, nonatomic) IBOutlet UIView *cameraView;

- (IBAction)backButtonWasPressed:(id)sender;
@end

@implementation QRCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    __weak typeof(self) weakSelf = self;
    self.scanningCompletion = ^(NSArray *codes) {
        
        [weakSelf.scanner stopScanning];
        
        AVMetadataMachineReadableCodeObject *code = codes.firstObject;
        
        if ([weakSelf.delegate respondsToSelector:@selector(qrCodeScanned:)]) {
            [weakSelf.delegate qrCodeScanned:[QRCodeManager getNewPaymentDictionaryFromString:code.stringValue]];
        }
        
        [weakSelf backButtonWasPressed:nil];
    };
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.scanner = [[MTBBarcodeScanner alloc] initWithMetadataObjectTypes:@[AVMetadataObjectTypeUPCECode,
                                                                            AVMetadataObjectTypeCode39Code,
                                                                            AVMetadataObjectTypeCode39Mod43Code,
                                                                            AVMetadataObjectTypeEAN13Code,
                                                                            AVMetadataObjectTypeEAN8Code,
                                                                            AVMetadataObjectTypeCode93Code,
                                                                            AVMetadataObjectTypeCode128Code,
                                                                            AVMetadataObjectTypePDF417Code,
                                                                            AVMetadataObjectTypeQRCode,
                                                                            AVMetadataObjectTypeAztecCode]
                                                              previewView:self.cameraView];
    __weak typeof(self) weakSelf = self;
    [MTBBarcodeScanner requestCameraPermissionWithSuccess:^(BOOL success) {
        if (success)
        {
            weakSelf.scanner.resultBlock = weakSelf.scanningCompletion;
            [weakSelf.scanner startScanning];
            
        } else
        {
            [weakSelf showCameraPermissionAlertWithTitle:@"Error" mesage:@"Camera premission not found" andActions:nil];
        }
    }];
}

- (IBAction)backButtonWasPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
#warning Dismiss commented
        //TODO : fix logic
//        if ([self.delegate respondsToSelector:@selector(showNextVC)]) {
//            [self.delegate showNextVC];
//        }
    }];
}
@end