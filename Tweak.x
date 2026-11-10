#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Edit these to change the look
#define TIME_FORMAT @"h:mm:ss a"        // 6:14:23 PM
#define DATE_FORMAT @"EEEE MMMM d y"    // Monday November 9 2026

@interface _UIStatusBarStringView : UILabel
@end

static NSHashTable *gViews;
static NSDateFormatter *gTimeFmt, *gDateFmt;
static BOOL gBypass = NO;
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

static NSInteger kindFor(id view, NSString *incoming) {
    NSInteger kind = [objc_getAssociatedObject(view, kKind) integerValue];
    if (!kind) {
        kind = classify(incoming);
        if (kind) {
            objc_setAssociatedObject(view, kKind, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [gViews addObject:view];
        }
    }
    return kind;
}

%hook _UIStatusBarStringView

- (void)setText:(NSString *)text {
    if (gBypass) { %orig; return; }
    NSInteger kind = kindFor(self, text);
    if (kind) { %orig(textFor(kind)); } else { %orig; }
}

- (void)setAttributedText:(NSAttributedString *)text {
    if (gBypass) { %orig; return; }
    NSInteger kind = kindFor(self, text.string);
    if (kind && text) {
        NSMutableAttributedString *m = [text mutableCopy];
        [m.mutableString setString:textFor(kind)];
        %orig(m);
    } else {
        %orig;
    }
}

%end

static void tick(void) {
    for (_UIStatusBarStringView *v in gViews.allObjects) {
        NSInteger kind = [objc_getAssociatedObject(v, kKind) integerValue];
        if (!kind) continue;
        NSString *t = textFor(kind);
        if ([v.text isEqualToString:t]) continue;
        gBypass = YES;
        v.text = t;
        gBypass = NO;
    }
}

%ctor {
    gViews = [NSHashTable weakObjectsHashTable];
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
