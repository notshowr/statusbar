#import <UIKit/UIKit.h>

// Edit these to change the look (ICU/NSDateFormatter patterns)
#define TIME_FORMAT @"h:mm:ss a"          // 6:14:23 PM
#define DATE_FORMAT @"EEEE, MMMM d y"     // Monday, November 9 2026

@interface _UIStatusBarStringView : UILabel
@end

@interface _UIStatusBarTimeItem : NSObject
@end

static NSHashTable *gItems;
static NSDateFormatter *gTimeFmt, *gDateFmt;

static void setLabel(id item, NSString *key, NSString *text) {
    @try {
        _UIStatusBarStringView *v = [item valueForKey:key];
        if ([v isKindOfClass:[UILabel class]] && ![v.text isEqualToString:text]) {
            v.text = text;
        }
    } @catch (__unused NSException *e) {}
}

static void applyTo(id item) {
    NSDate *now = [NSDate date];
    NSString *t = [gTimeFmt stringFromDate:now];
    NSString *d = [gDateFmt stringFromDate:now];
    setLabel(item, @"timeView", t);
    setLabel(item, @"shortTimeView", t);
    setLabel(item, @"pillTimeView", t);
    setLabel(item, @"dateView", d);
}

%hook _UIStatusBarTimeItem
- (id)applyUpdate:(id)update toDisplayItem:(id)displayItem {
    id r = %orig;
    [gItems addObject:self];
    applyTo(self);
    return r;
}
%end

%ctor {
    gItems = [NSHashTable weakObjectsHashTable];
    gTimeFmt = [NSDateFormatter new];
    gTimeFmt.dateFormat = TIME_FORMAT;
    gDateFmt = [NSDateFormatter new];
    gDateFmt.dateFormat = DATE_FORMAT;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *t = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            for (id item in gItems.allObjects) applyTo(item);
        }];
        [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    });
}
