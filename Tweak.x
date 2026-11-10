#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Edit these to change the look
#define TIME_FORMAT @"h:mm:ss a"        // 6:14:23 PM
#define DATE_FORMAT @"EEEE MMMM d y"    // Monday November 9 2026

static NSHashTable *gLabels;
static NSDateFormatter *gTimeFmt, *gDateFmt;
static const void *kKind = &kKind; // 1 = time label, 2 = date label

static NSInteger classify(NSString *s) {
    if (!s.length) return 0;
    static NSRegularExpression *timeRx, *dateRx;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        timeRx = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}[:.]\\d{2}" options:0 error:nil];
        dateRx = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z]{3,9},? [A-Za-z]{3,9}\\.? \\d{1,2}$" options:0 error:nil];
    });
    NSRange r = NSMakeRange(0, s.length);
    if ([timeRx firstMatchInString:s options:0 range:r]) return 1;
    if ([dateRx firstMatchInString:s options:0 range:r]) return 2;
    return 0;
}

static NSString *textFor(NSInteger kind) {
    NSDate *now = [NSDate date];
    return kind == 1 ? [gTimeFmt stringFromDate:now] : [gDateFmt stringFromDate:now];
}

%hook UILabel

- (void)didMoveToWindow {
    %orig;
    if (self.window &&
        [NSStringFromClass([self class]) rangeOfString:@"StatusBar"].location != NSNotFound) {
        [gLabels addObject:self];
    }
}

%end

static void tick(void) {
    for (UILabel *v in gLabels.allObjects) {
        NSNumber *known = objc_getAssociatedObject(v, kKind);
        NSInteger kind = known ? known.integerValue : 0;
        if (!kind) {
            kind = classify(v.text);
            if (!kind) continue;
            objc_setAssociatedObject(v, kKind, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSString *t = textFor(kind);
        if ([v.text isEqualToString:t]) continue;
        NSAttributedString *a = v.attributedText;
        if (a.length) {
            NSMutableAttributedString *m = [a mutableCopy];
            [m.mutableString setString:t];
            v.attributedText = m;
        } else {
            v.text = t;
        }
    }
}

%ctor {
    gLabels = [NSHashTable weakObjectsHashTable];
    gTimeFmt = [NSDateFormatter new];
    gTimeFmt.dateFormat = TIME_FORMAT;
    gDateFmt = [NSDateFormatter new];
    gDateFmt.dateFormat = DATE_FORMAT;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *t = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            tick();
        }];
        [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    });
}
