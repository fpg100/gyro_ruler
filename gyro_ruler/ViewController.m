//
//  ViewController.m
//  gyro_ruler
//
//  Created by Matsumoto Taichi on 5/7/13.
//  Copyright (c) 2013 Matsumoto Taichi. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import "ViewController.h"

@interface ViewController () 

// @property (nonatomic, retain) UIAccelerometer* accelerometer;
@property (nonatomic, retain) CMMotionManager *motionManager;
@property (nonatomic, retain) CMDeviceMotion *lastMotion;
@property (nonatomic, assign) BOOL measuring;
@property (nonatomic, retain) NSMutableArray *plots;
@property (nonatomic, retain) CMDeviceMotion *lastPlot;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, retain) UIImagePickerController* picker;
@property (nonatomic, retain) UIView *cameraOverlay;
@property (nonatomic, retain) UIButton *toggleButton;
@property (nonatomic, retain) UILabel *resultLabel;

- (void)startCamera;
- (void)setupMotionManager;
- (void)calc:(NSArray *)plots;

@end

@implementation ViewController

- (void)awakeFromNib {
	[super awakeFromNib];

	self.measuring = NO;
	[self addObserver:self
		   forKeyPath:@"measuring"
			   options:NSKeyValueObservingOptionNew
			  context:nil];
	
	[self setupMotionManager];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self startCamera];
}

- (void)dealloc {
	[self removeObserver:self forKeyPath:@"measuring"];
	
	self.motionManager = nil;
	self.plots = nil;
	self.lastPlot = nil;
	self.cameraOverlay = nil;
	self.picker = nil;
	self.toggleButton = nil;
	self.resultLabel = nil;
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
	change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"measuring"]) {
		[self.toggleButton setTitle:self.measuring ? @"Stop" : @"Start To Measure"
						   forState:UIControlStateNormal];
		if (self.measuring) {
			self.resultLabel.text = @"Measuring";
		}
	}
}


- (void)push:(id)sender {
    // off => on	
	if (!self.measuring) {  
		self.plots = [NSMutableArray array];
		self.startTime = self.lastPlot.timestamp;
	}
    // on => off	
	else {                  
		[self calc:self.plots];
	}
	self.measuring = !self.measuring;
}

- (void)startCamera {
	int screenWidth = [[UIScreen mainScreen] bounds].size.width;
	
	self.cameraOverlay = [[[UIView alloc] initWithFrame:self.view.bounds] autorelease];
	self.toggleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[self.toggleButton setTitle:@"Start to Measure" forState:UIControlStateNormal];
	self.resultLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, screenWidth, 44)] autorelease];
	self.resultLabel.backgroundColor = [UIColor whiteColor];
	self.resultLabel.text = @"Result will be displayed here.";
	self.resultLabel.textAlignment = NSTextAlignmentCenter;
	[self.cameraOverlay addSubview:self.resultLabel];

	int buttonWidth = 150;
	int buttonHeight = 44;
	int x = (screenWidth - buttonWidth) / 2;
	int y = [[UIScreen mainScreen] bounds].size.height - 44;
	self.toggleButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
	[self.cameraOverlay addSubview:self.toggleButton];
	[self.toggleButton addTarget:self
						  action:@selector(push:)
				forControlEvents:UIControlEventTouchUpInside];
		
    self.picker = [[[UIImagePickerController alloc] init] autorelease];
 
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        self.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        self.picker.showsCameraControls = NO;
        self.picker.cameraOverlayView = self.cameraOverlay;
		self.picker.delegate = self;
		[self presentViewController:self.picker animated:YES completion:nil];
    }
}

- (void)setupMotionManager {
	self.motionManager = [[[CMMotionManager alloc] init] autorelease];
	if ([self.motionManager isDeviceMotionAvailable]) {
		[self.motionManager setDeviceMotionUpdateInterval:0.005];

		[self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:
					  ^(CMDeviceMotion *deviceMotion, NSError *error) {
				if (self.measuring) {
					[self.plots addObject:deviceMotion];
				}
				else {
					self.lastPlot = deviceMotion;
				}
		}];
	}
}

struct Vector { float x, y, z; };
typedef struct Vector Vector;
- (void)calc:(NSArray *)plots {
	Vector p = {0}, v = {0}; 	// assume initial velocity is 0 and position is 0 as well
	NSTimeInterval last = self.startTime;
	for (CMDeviceMotion *m in plots) {
		CMAcceleration acc = m.userAcceleration;
		NSTimeInterval delta = m.timestamp - last;

		v.x += acc.x * delta * 9.8; v.y += acc.y * delta * 9.8; v.z += acc.z * delta * 9.8;
		p.x += v.x * delta;	p.y += v.y * delta;	p.z += v.z * delta;
				
		last = m.timestamp;
	}

	// calculate distance between first point and last point
	double distance = sqrt(pow(p.x, 2) + pow(p.y, 2) + pow(p.x, 2));
	NSLog(@"%f m", distance);

	self.resultLabel.text = [NSString stringWithFormat:@"%0.2f cm", distance * 100];
}


#pragma mark -
#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {

	[[self.picker presentingViewController]
        dismissViewControllerAnimated:YES completion:nil];	
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[[self.picker presentingViewController]
        dismissViewControllerAnimated:YES completion:nil];
}

@end
