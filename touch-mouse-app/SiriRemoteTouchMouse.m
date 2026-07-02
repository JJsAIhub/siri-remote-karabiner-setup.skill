// 监听 Apple TV 遥控器中间触摸面，并把滑动转换成鼠标移动。
// 说明：这里使用 macOS 私有的 MultitouchSupport 接口，和 Karabiner-MultitouchExtension 的底层路线一致。

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/IOKitLib.h>
#import <math.h>
#import <stdarg.h>
#import <unistd.h>

typedef struct {
  float x;
  float y;
} MTPoint;

typedef struct {
  MTPoint position;
  MTPoint velocity;
} MTReadout;

typedef struct {
  int frame;
  double timestamp;
  int identifier;
  int state;
  int fingerId;
  int handId;
  MTReadout normalized;
  float size;
  int pressure;
  float angle;
  float majorAxis;
  float minorAxis;
  MTReadout absoluteVector;
  int unknown1[2];
  float zDensity;
} Finger;

typedef struct MTDevice *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(MTDeviceRef, Finger *, int, double, int);

extern CFMutableArrayRef MTDeviceCreateList(void);
extern io_service_t MTDeviceGetService(MTDeviceRef);
extern void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
extern void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
extern void MTDeviceStart(MTDeviceRef, int);
extern void MTDeviceStop(MTDeviceRef, int);

typedef struct {
  bool active;
  int identifier;
  float x;
  float y;
} TouchState;

typedef struct {
  int dx;
  int dy;
} MouseDelta;

typedef struct {
  bool active;
  int signature;
} FallbackTouchState;

typedef struct {
  bool hasPosition;
  CGPoint position;
  double suppressedUntilTime;
} MousePositionGuard;

static NSMutableArray *gRemoteDevices;
static TouchState gTouchState = {false, -1, 0.0f, 0.0f};
static FallbackTouchState gFallbackTouchState = {false, 0};
static MousePositionGuard gFallbackMouseGuard = {false, {0.0, 0.0}, 0.0};
static IOHIDManagerRef gRemoteHIDManager = NULL;
static NSDate *gLastSeenToggleDate = nil;
static double gLastFallbackPauseLogTime = 0.0;
static int gRawFrameLogCount = 0;
static const int kAppleVendorID = 76;
static const int kSiriRemoteProductID = 789;
static const float kMouseScale = 1150.0f;
static const int kFallbackMouseStep = 16;
static const NSTimeInterval kToggleSignalFreshSeconds = 5.0;
static const double kExternalMouseCooldownSeconds = 0.45;
static const double kPauseLogIntervalSeconds = 1.0;
static bool gEnableKarabinerFallback = true;
static bool gUnsafeKarabinerFallback = false;
static bool gTouchMouseEnabled = false;
static NSString *const kKarabinerCLIPath = @"/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli";
static NSString *const kKarabinerMultitouchExtensionPath = @"/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-MultitouchExtension.app";
static NSString *const kKarabinerToggleSignalPath = @"/tmp/SiriRemoteTouchMouse.toggle";
static NSString *const kLogFilePath = @"/tmp/SiriRemoteTouchMouse.log";

static void ResetLogFile(void) {
  [@"" writeToFile:kLogFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void LogLine(const char *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args];
  va_end(args);

  printf("%s\n", message.UTF8String);
  fflush(stdout);

  NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:kLogFilePath];
  if (!file) {
    [message writeToFile:kLogFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    file = [NSFileHandle fileHandleForWritingAtPath:kLogFilePath];
  }
  if (!file) {
    return;
  }

  [file seekToEndOfFile];
  NSString *line = [message stringByAppendingString:@"\n"];
  [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
  [file closeFile];
}

static CFTypeRef CopyRegistryPropertyUpTree(io_registry_entry_t entry, CFStringRef key) {
  io_registry_entry_t current = entry;

  while (current != IO_OBJECT_NULL) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(current, key, kCFAllocatorDefault, 0);
    if (value) {
      if (current != entry) {
        IOObjectRelease(current);
      }
      return value;
    }

    io_registry_entry_t parent = IO_OBJECT_NULL;
    kern_return_t kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent);
    if (current != entry) {
      IOObjectRelease(current);
    }
    if (kr != KERN_SUCCESS) {
      break;
    }
    current = parent;
  }

  return NULL;
}

static int NumberProperty(io_registry_entry_t entry, CFStringRef key, int fallback) {
  CFTypeRef value = CopyRegistryPropertyUpTree(entry, key);
  if (!value) {
    return fallback;
  }

  int result = fallback;
  if (CFGetTypeID(value) == CFNumberGetTypeID()) {
    CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &result);
  }
  CFRelease(value);

  return result;
}

static NSString *StringProperty(io_registry_entry_t entry, CFStringRef key) {
  CFTypeRef value = CopyRegistryPropertyUpTree(entry, key);
  if (!value) {
    return @"";
  }

  NSString *result = @"";
  if (CFGetTypeID(value) == CFStringGetTypeID()) {
    result = [(__bridge NSString *)value copy];
  }
  CFRelease(value);

  return result;
}

static bool IsSiriRemoteTouchDevice(MTDeviceRef device) {
  io_service_t service = MTDeviceGetService(device);
  if (service == IO_OBJECT_NULL) {
    return false;
  }

  int vendorID = NumberProperty(service, CFSTR("VendorID"), -1);
  int productID = NumberProperty(service, CFSTR("ProductID"), -1);

  return vendorID == kAppleVendorID && productID == kSiriRemoteProductID;
}

static NSString *DeviceSummary(MTDeviceRef device) {
  io_service_t service = MTDeviceGetService(device);
  if (service == IO_OBJECT_NULL) {
    return @"<unknown multitouch device>";
  }

  int vendorID = NumberProperty(service, CFSTR("VendorID"), -1);
  int productID = NumberProperty(service, CFSTR("ProductID"), -1);
  NSString *product = StringProperty(service, CFSTR("Product"));
  NSString *transport = StringProperty(service, CFSTR("Transport"));
  NSString *uniqueID = StringProperty(service, CFSTR("PhysicalDeviceUniqueID"));

  return [NSString stringWithFormat:@"product=\"%@\" vendor=%d productId=%d transport=\"%@\" id=\"%@\"",
                                    product,
                                    vendorID,
                                    productID,
                                    transport,
                                    uniqueID];
}

static MouseDelta MapTouchDeltaToMouseDelta(float previousX, float previousY, float nextX, float nextY) {
  float deltaX = nextX - previousX;
  float deltaY = nextY - previousY;

  MouseDelta delta;
  delta.dx = (int)lrintf(deltaX * kMouseScale);
  delta.dy = (int)lrintf(-deltaY * kMouseScale);
  return delta;
}

static void MoveMouseBy(MouseDelta delta) {
  if (delta.dx == 0 && delta.dy == 0) {
    return;
  }

  CGEventRef event = CGEventCreate(NULL);
  if (!event) {
    return;
  }

  CGPoint current = CGEventGetLocation(event);
  CFRelease(event);

  CGPoint next = CGPointMake(current.x + delta.dx, current.y + delta.dy);
  CGWarpMouseCursorPosition(next);
  CGAssociateMouseAndMouseCursorPosition(true);
}

static CGPoint CurrentMousePosition(void) {
  CGEventRef event = CGEventCreate(NULL);
  if (!event) {
    return CGPointMake(0, 0);
  }

  CGPoint current = CGEventGetLocation(event);
  CFRelease(event);
  return current;
}

static int IntValue(NSDictionary *dictionary, NSString *key) {
  id value = dictionary[key];
  if ([value respondsToSelector:@selector(intValue)]) {
    return [value intValue];
  }
  return 0;
}

static bool ShouldSuppressFallbackForExternalMouseMovement(MousePositionGuard *guard,
                                                           CGPoint current,
                                                           double threshold,
                                                           double nowTime,
                                                           double cooldownSeconds) {
  if (nowTime < guard->suppressedUntilTime) {
    guard->position = current;
    return true;
  }

  if (!guard->hasPosition) {
    guard->hasPosition = true;
    guard->position = current;
    return false;
  }

  double dx = current.x - guard->position.x;
  double dy = current.y - guard->position.y;
  guard->position = current;

  if (fabs(dx) <= threshold && fabs(dy) <= threshold) {
    return false;
  }

  guard->suppressedUntilTime = nowTime + cooldownSeconds;
  return true;
}

static void RecordFallbackMouseMove(MousePositionGuard *guard, CGPoint before, MouseDelta delta) {
  guard->hasPosition = true;
  guard->position = CGPointMake(before.x + delta.dx, before.y + delta.dy);
}

static bool ShouldLogThrottledPause(double *lastLogTime, double nowTime, double intervalSeconds) {
  if (*lastLogTime <= 0.0 || nowTime - *lastLogTime >= intervalSeconds) {
    *lastLogTime = nowTime;
    return true;
  }
  return false;
}

static int KarabinerFallbackSignature(int left,
                                      int right,
                                      int upper,
                                      int lower,
                                      int leftQuarter,
                                      int rightQuarter,
                                      int upperQuarter,
                                      int lowerQuarter) {
  return (left << 0) |
         (right << 3) |
         (upper << 6) |
         (lower << 9) |
         (leftQuarter << 12) |
         (rightQuarter << 15) |
         (upperQuarter << 18) |
         (lowerQuarter << 21);
}

static bool MapKarabinerFallbackVariablesToMouseDelta(NSDictionary *variables,
                                                      FallbackTouchState *state,
                                                      MouseDelta *delta) {
  delta->dx = 0;
  delta->dy = 0;

  int total = IntValue(variables, @"multitouch_extension_finger_count_total");
  if (total != 1) {
    state->active = false;
    state->signature = 0;
    return false;
  }

  int left = IntValue(variables, @"multitouch_extension_finger_count_left_half_area");
  int right = IntValue(variables, @"multitouch_extension_finger_count_right_half_area");
  int upper = IntValue(variables, @"multitouch_extension_finger_count_upper_half_area");
  int lower = IntValue(variables, @"multitouch_extension_finger_count_lower_half_area");
  int leftQuarter = IntValue(variables, @"multitouch_extension_finger_count_left_quarter_area");
  int rightQuarter = IntValue(variables, @"multitouch_extension_finger_count_right_quarter_area");
  int upperQuarter = IntValue(variables, @"multitouch_extension_finger_count_upper_quarter_area");
  int lowerQuarter = IntValue(variables, @"multitouch_extension_finger_count_lower_quarter_area");
  int signature = KarabinerFallbackSignature(left,
                                             right,
                                             upper,
                                             lower,
                                             leftQuarter,
                                             rightQuarter,
                                             upperQuarter,
                                             lowerQuarter);

  if (!state->active) {
    state->active = true;
    state->signature = signature;
    return false;
  }

  if (state->signature == signature) {
    return false;
  }

  state->signature = signature;

  int xScore = (right - left) + (rightQuarter - leftQuarter);
  int yScore = (lower - upper) + (lowerQuarter - upperQuarter);
  delta->dx = xScore * kFallbackMouseStep;
  delta->dy = yScore * kFallbackMouseStep;

  return delta->dx != 0 || delta->dy != 0;
}

static bool ShouldToggleFromSignalDate(NSDate *signalDate, NSDate *nowDate, NSDate *__strong *lastSeenDate) {
  if (!signalDate || !nowDate) {
    return false;
  }

  if (*lastSeenDate && [signalDate compare:*lastSeenDate] != NSOrderedDescending) {
    return false;
  }

  if ([nowDate timeIntervalSinceDate:signalDate] > kToggleSignalFreshSeconds) {
    return false;
  }

  *lastSeenDate = signalDate;
  return true;
}

static NSDate *ReadKarabinerToggleSignalDate(void) {
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:kKarabinerToggleSignalPath error:nil];
  id date = attributes[NSFileModificationDate];
  if (![date isKindOfClass:[NSDate class]]) {
    return nil;
  }
  return date;
}

static void ToggleTouchMouseMode(NSString *reason) {
  gTouchMouseEnabled = !gTouchMouseEnabled;
  gTouchState.active = false;
  gTouchState.identifier = -1;
  gFallbackTouchState.active = false;
  gFallbackTouchState.signature = 0;
  gFallbackMouseGuard.hasPosition = false;
  gFallbackMouseGuard.position = CGPointMake(0, 0);
  gFallbackMouseGuard.suppressedUntilTime = 0.0;
  gLastFallbackPauseLogTime = 0.0;
  LogLine("[mode] touch mouse %s by %s",
          gTouchMouseEnabled ? "enabled" : "disabled",
          reason.UTF8String);
}

static void PollTouchMouseModeToggle(void) {
  NSDate *signalDate = ReadKarabinerToggleSignalDate();
  if (ShouldToggleFromSignalDate(signalDate, [NSDate date], &gLastSeenToggleDate)) {
    ToggleTouchMouseMode(@"selection-double-click");
  }
}

static NSDictionary *ReadKarabinerVariables(NSString *argument) {
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = kKarabinerCLIPath;
  task.arguments = @[argument];

  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launch];
    [task waitUntilExit];
  } @catch (NSException *exception) {
    return nil;
  }

  if (task.terminationStatus != 0) {
    return nil;
  }

  NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
  if (data.length == 0) {
    return nil;
  }

  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![json isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  return json;
}

static NSDictionary *ReadKarabinerMultitouchVariables(void) {
  return ReadKarabinerVariables(@"--list-multitouch-extension-variables");
}

static void StartKarabinerMultitouchExtension(void) {
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/open";
  task.arguments = @[@"-na", kKarabinerMultitouchExtensionPath];
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];

  @try {
    [task launch];
  } @catch (NSException *exception) {
    fprintf(stderr, "[fallback] 无法启动 Karabiner-MultitouchExtension: %s\n", exception.reason.UTF8String);
  }
}

static void PollKarabinerFallback(void) {
  PollTouchMouseModeToggle();

  if (!gTouchMouseEnabled && !gUnsafeKarabinerFallback) {
    return;
  }

  NSDictionary *variables = ReadKarabinerMultitouchVariables();
  if (!variables) {
    return;
  }

  CGPoint currentMouse = CurrentMousePosition();
  double nowTime = [NSDate timeIntervalSinceReferenceDate];
  if (ShouldSuppressFallbackForExternalMouseMovement(&gFallbackMouseGuard,
                                                     currentMouse,
                                                     2.0,
                                                     nowTime,
                                                     kExternalMouseCooldownSeconds)) {
    gFallbackTouchState.active = false;
    gFallbackTouchState.signature = 0;
    if (ShouldLogThrottledPause(&gLastFallbackPauseLogTime, nowTime, kPauseLogIntervalSeconds)) {
      LogLine("[fallback] pause: detected normal mouse movement");
    }
    return;
  }

  int left = IntValue(variables, @"multitouch_extension_finger_count_left_half_area");
  int right = IntValue(variables, @"multitouch_extension_finger_count_right_half_area");
  int upper = IntValue(variables, @"multitouch_extension_finger_count_upper_half_area");
  int lower = IntValue(variables, @"multitouch_extension_finger_count_lower_half_area");
  int total = IntValue(variables, @"multitouch_extension_finger_count_total");

  MouseDelta delta = {0, 0};
  if (MapKarabinerFallbackVariablesToMouseDelta(variables, &gFallbackTouchState, &delta)) {
    LogLine("[fallback] total=%d left=%d right=%d upper=%d lower=%d dx=%d dy=%d",
            total,
            left,
            right,
            upper,
            lower,
            delta.dx,
            delta.dy);
    MoveMouseBy(delta);
    RecordFallbackMouseMove(&gFallbackMouseGuard, currentMouse, delta);
  }
}

static void StartKarabinerFallbackTimer(void) {
  if (!gEnableKarabinerFallback) {
    printf("[fallback] 已关闭 Karabiner 备用模式，只使用设备级直连监听。\n");
    fflush(stdout);
    return;
  }

  if (gUnsafeKarabinerFallback) {
    LogLine("[fallback] 启动不安全模式：会读取所有多点触控变量，可能影响正常触控板。");
  } else {
    LogLine("[fallback] 启动安全门模式：只有遥控器先产生输入后，才短暂允许鼠标移动。");
  }
  StartKarabinerMultitouchExtension();

  [NSTimer scheduledTimerWithTimeInterval:0.08
                                  repeats:YES
                                    block:^(__unused NSTimer *timer) {
                                      PollKarabinerFallback();
                                    }];
}

static void RemoteHIDValueCallback(__unused void *context,
                                   __unused IOReturn result,
                                   __unused void *sender,
                                   IOHIDValueRef value) {
  IOHIDElementRef element = IOHIDValueGetElement(value);
  if (!element) {
    return;
  }

  IOHIDDeviceRef device = IOHIDElementGetDevice(element);
  if (!device) {
    return;
  }

  CFTypeRef vendorValue = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
  CFTypeRef productValue = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
  int vendorID = -1;
  int productID = -1;

  if (vendorValue && CFGetTypeID(vendorValue) == CFNumberGetTypeID()) {
    CFNumberGetValue((CFNumberRef)vendorValue, kCFNumberIntType, &vendorID);
  }
  if (productValue && CFGetTypeID(productValue) == CFNumberGetTypeID()) {
    CFNumberGetValue((CFNumberRef)productValue, kCFNumberIntType, &productID);
  }

  if (vendorID != kAppleVendorID || productID != kSiriRemoteProductID) {
    return;
  }

  CFIndex integerValue = IOHIDValueGetIntegerValue(value);
  if (integerValue != 0) {
    if (!gTouchMouseEnabled) {
      gTouchMouseEnabled = true;
      LogLine("[mode] touch mouse enabled by hid-input");
    }
  }
}

static CFDictionaryRef CreateHIDMatchingDictionary(void) {
  CFNumberRef vendor = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &(int){kAppleVendorID});
  CFNumberRef product = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &(int){kSiriRemoteProductID});
  const void *keys[] = {CFSTR(kIOHIDVendorIDKey), CFSTR(kIOHIDProductIDKey)};
  const void *values[] = {vendor, product};
  CFDictionaryRef dictionary = CFDictionaryCreate(kCFAllocatorDefault,
                                                  keys,
                                                  values,
                                                  2,
                                                  &kCFTypeDictionaryKeyCallBacks,
                                                  &kCFTypeDictionaryValueCallBacks);
  CFRelease(vendor);
  CFRelease(product);
  return dictionary;
}

static void StartRemoteHIDArming(void) {
  if (!gEnableKarabinerFallback || gUnsafeKarabinerFallback) {
    return;
  }

  gRemoteHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
  if (!gRemoteHIDManager) {
    LogLine("[arm] 无法创建 HID 管理器，备用模式不会自动解锁。");
    return;
  }

  CFDictionaryRef matching = CreateHIDMatchingDictionary();
  IOHIDManagerSetDeviceMatching(gRemoteHIDManager, matching);
  CFRelease(matching);

  IOHIDManagerRegisterInputValueCallback(gRemoteHIDManager, RemoteHIDValueCallback, NULL);
  IOHIDManagerScheduleWithRunLoop(gRemoteHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

  IOReturn result = IOHIDManagerOpen(gRemoteHIDManager, kIOHIDOptionsTypeNone);
  if (result != kIOReturnSuccess) {
    LogLine("[arm] HID 监听打开失败：0x%x。备用模式会保持锁住，避免影响普通鼠标。", result);
    IOHIDManagerUnscheduleFromRunLoop(gRemoteHIDManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    CFRelease(gRemoteHIDManager);
    gRemoteHIDManager = NULL;
    return;
  }

  LogLine("[arm] 正在监听 Apple TV 遥控器 HID 输入，用来解锁安全备用模式。");
}

static int ContactFrameCallback(MTDeviceRef device, Finger *fingers, int fingerCount, double timestamp, int frame) {
  if (!IsSiriRemoteTouchDevice(device)) {
    return 0;
  }
  if (!gTouchMouseEnabled && !gUnsafeKarabinerFallback) {
    return 0;
  }

  if (gRawFrameLogCount < 120) {
    printf("[raw] frame=%d fingerCount=%d time=%.4f\n", frame, fingerCount, timestamp);
    for (int i = 0; i < fingerCount; i++) {
      Finger finger = fingers[i];
      printf("[raw]   index=%d id=%d state=%d x=%.4f y=%.4f size=%.4f\n",
             i,
             finger.identifier,
             finger.state,
             finger.normalized.position.x,
             finger.normalized.position.y,
             finger.size);
    }
    fflush(stdout);
    gRawFrameLogCount++;
  }

  bool sawTouchedFinger = false;

  for (int i = 0; i < fingerCount; i++) {
    Finger finger = fingers[i];

    // state == 4 表示真正接触；其他状态多为悬停/接近，先不拿来移动鼠标，避免漂移。
    if (finger.state != 4) {
      continue;
    }

    sawTouchedFinger = true;
    float x = finger.normalized.position.x;
    float y = finger.normalized.position.y;

    if (!gTouchState.active || gTouchState.identifier != finger.identifier) {
      gTouchState.active = true;
      gTouchState.identifier = finger.identifier;
      gTouchState.x = x;
      gTouchState.y = y;
      printf("[touch] begin id=%d x=%.4f y=%.4f frame=%d time=%.4f\n",
             finger.identifier,
             x,
             y,
             frame,
             timestamp);
      fflush(stdout);
      continue;
    }

    MouseDelta delta = MapTouchDeltaToMouseDelta(gTouchState.x, gTouchState.y, x, y);
    gTouchState.x = x;
    gTouchState.y = y;

    if (delta.dx != 0 || delta.dy != 0) {
      printf("[touch] move id=%d x=%.4f y=%.4f dx=%d dy=%d\n",
             finger.identifier,
             x,
             y,
             delta.dx,
             delta.dy);
      fflush(stdout);
      MoveMouseBy(delta);
    }
  }

  if (!sawTouchedFinger && gTouchState.active) {
    printf("[touch] end id=%d\n", gTouchState.identifier);
    fflush(stdout);
    gTouchState.active = false;
    gTouchState.identifier = -1;
  }

  return 0;
}

static bool RunSelfTest(void) {
  MouseDelta right = MapTouchDeltaToMouseDelta(0.20f, 0.50f, 0.25f, 0.50f);
  MouseDelta up = MapTouchDeltaToMouseDelta(0.50f, 0.20f, 0.50f, 0.25f);
  MouseDelta tiny = MapTouchDeltaToMouseDelta(0.10f, 0.10f, 0.1001f, 0.1001f);
  FallbackTouchState fallbackState = {false, 0};
  MouseDelta fallbackDelta = {0, 0};
  MousePositionGuard mouseGuard = {false, CGPointMake(0, 0), 0.0};
  gUnsafeKarabinerFallback = false;

  bool ok = true;
  if (right.dx <= 0 || right.dy != 0) {
    fprintf(stderr, "[self-test] failed: right swipe mapped to dx=%d dy=%d\n", right.dx, right.dy);
    ok = false;
  }
  if (up.dx != 0 || up.dy >= 0) {
    fprintf(stderr, "[self-test] failed: upward swipe mapped to dx=%d dy=%d\n", up.dx, up.dy);
    ok = false;
  }
  if (abs(tiny.dx) > 1 || abs(tiny.dy) > 1) {
    fprintf(stderr, "[self-test] failed: tiny movement mapped too large dx=%d dy=%d\n", tiny.dx, tiny.dy);
    ok = false;
  }
  gUnsafeKarabinerFallback = true;
  if (!gUnsafeKarabinerFallback) {
    fprintf(stderr, "[self-test] failed: unsafe fallback flag should stay enabled\n");
    ok = false;
  }
  gUnsafeKarabinerFallback = false;

  NSDate *lastSeenToggleDate = nil;
  NSDate *nowDate = [NSDate dateWithTimeIntervalSince1970:100.0];
  NSDate *freshToggleDate = [NSDate dateWithTimeIntervalSince1970:99.0];
  NSDate *staleToggleDate = [NSDate dateWithTimeIntervalSince1970:90.0];
  double lastPauseLogTime = 0.0;

  if (!ShouldToggleFromSignalDate(freshToggleDate, nowDate, &lastSeenToggleDate)) {
    fprintf(stderr, "[self-test] failed: fresh toggle file should switch mode\n");
    ok = false;
  }
  if (ShouldToggleFromSignalDate(freshToggleDate, nowDate, &lastSeenToggleDate)) {
    fprintf(stderr, "[self-test] failed: repeated toggle file should not switch mode again\n");
    ok = false;
  }
  if (ShouldToggleFromSignalDate(staleToggleDate, nowDate, &lastSeenToggleDate)) {
    fprintf(stderr, "[self-test] failed: stale toggle file should not switch mode\n");
    ok = false;
  }

  NSDictionary *rightLowerTouch = @{
    @"multitouch_extension_finger_count_total": @1,
    @"multitouch_extension_finger_count_left_half_area": @0,
    @"multitouch_extension_finger_count_right_half_area": @1,
    @"multitouch_extension_finger_count_upper_half_area": @0,
    @"multitouch_extension_finger_count_lower_half_area": @1,
    @"multitouch_extension_finger_count_left_quarter_area": @0,
    @"multitouch_extension_finger_count_right_quarter_area": @1,
    @"multitouch_extension_finger_count_upper_quarter_area": @0,
    @"multitouch_extension_finger_count_lower_quarter_area": @1
  };
  NSDictionary *leftLowerTouch = @{
    @"multitouch_extension_finger_count_total": @1,
    @"multitouch_extension_finger_count_left_half_area": @1,
    @"multitouch_extension_finger_count_right_half_area": @0,
    @"multitouch_extension_finger_count_upper_half_area": @0,
    @"multitouch_extension_finger_count_lower_half_area": @1,
    @"multitouch_extension_finger_count_left_quarter_area": @1,
    @"multitouch_extension_finger_count_right_quarter_area": @0,
    @"multitouch_extension_finger_count_upper_quarter_area": @0,
    @"multitouch_extension_finger_count_lower_quarter_area": @1
  };
  NSDictionary *multiFingerTouch = @{
    @"multitouch_extension_finger_count_total": @3,
    @"multitouch_extension_finger_count_left_half_area": @0,
    @"multitouch_extension_finger_count_right_half_area": @3,
    @"multitouch_extension_finger_count_upper_half_area": @2,
    @"multitouch_extension_finger_count_lower_half_area": @1,
    @"multitouch_extension_finger_count_left_quarter_area": @0,
    @"multitouch_extension_finger_count_right_quarter_area": @3,
    @"multitouch_extension_finger_count_upper_quarter_area": @2,
    @"multitouch_extension_finger_count_lower_quarter_area": @1
  };

  if (MapKarabinerFallbackVariablesToMouseDelta(rightLowerTouch, &fallbackState, &fallbackDelta)) {
    fprintf(stderr, "[self-test] failed: first fallback snapshot should only arm movement\n");
    ok = false;
  }
  if (MapKarabinerFallbackVariablesToMouseDelta(rightLowerTouch, &fallbackState, &fallbackDelta)) {
    fprintf(stderr, "[self-test] failed: repeated fallback snapshot should not move the mouse\n");
    ok = false;
  }
  if (!MapKarabinerFallbackVariablesToMouseDelta(leftLowerTouch, &fallbackState, &fallbackDelta) ||
      fallbackDelta.dx >= 0 ||
      fallbackDelta.dy <= 0) {
    fprintf(stderr, "[self-test] failed: changed fallback snapshot should move left/down, got dx=%d dy=%d\n",
            fallbackDelta.dx,
            fallbackDelta.dy);
    ok = false;
  }
  if (MapKarabinerFallbackVariablesToMouseDelta(multiFingerTouch, &fallbackState, &fallbackDelta)) {
    fprintf(stderr, "[self-test] failed: multi-finger fallback snapshot should be ignored\n");
    ok = false;
  }

  if (ShouldSuppressFallbackForExternalMouseMovement(&mouseGuard, CGPointMake(100, 100), 2.0, 10.0, 0.45)) {
    fprintf(stderr, "[self-test] failed: first mouse sample should not suppress fallback\n");
    ok = false;
  }
  RecordFallbackMouseMove(&mouseGuard, CGPointMake(100, 100), (MouseDelta){16, -16});
  if (ShouldSuppressFallbackForExternalMouseMovement(&mouseGuard, CGPointMake(116, 84), 2.0, 10.1, 0.45)) {
    fprintf(stderr, "[self-test] failed: app-created mouse movement should not suppress fallback\n");
    ok = false;
  }
  if (!ShouldSuppressFallbackForExternalMouseMovement(&mouseGuard, CGPointMake(140, 84), 2.0, 10.2, 0.45)) {
    fprintf(stderr, "[self-test] failed: external mouse movement should suppress fallback\n");
    ok = false;
  }
  if (!ShouldSuppressFallbackForExternalMouseMovement(&mouseGuard, CGPointMake(140, 84), 2.0, 10.4, 0.45)) {
    fprintf(stderr, "[self-test] failed: fallback should stay suppressed during cooldown\n");
    ok = false;
  }
  if (ShouldSuppressFallbackForExternalMouseMovement(&mouseGuard, CGPointMake(140, 84), 2.0, 10.8, 0.45)) {
    fprintf(stderr, "[self-test] failed: fallback should resume after cooldown\n");
    ok = false;
  }
  if (!ShouldLogThrottledPause(&lastPauseLogTime, 20.0, 1.0)) {
    fprintf(stderr, "[self-test] failed: first pause log should be allowed\n");
    ok = false;
  }
  if (ShouldLogThrottledPause(&lastPauseLogTime, 20.5, 1.0)) {
    fprintf(stderr, "[self-test] failed: pause log should be throttled inside interval\n");
    ok = false;
  }
  if (!ShouldLogThrottledPause(&lastPauseLogTime, 21.2, 1.0)) {
    fprintf(stderr, "[self-test] failed: pause log should resume after interval\n");
    ok = false;
  }

  if (ok) {
    printf("[self-test] passed\n");
  }
  return ok;
}

static void RegisterDevices(void) {
  CFMutableArrayRef devicesRef = MTDeviceCreateList();
  // Karabiner-MultitouchExtension 对这个返回值使用 takeUnretainedValue。
  // 这里也不要释放它，否则 MTDevice 引用可能过早失效，导致注册成功但收不到回调。
  NSArray *devices = (__bridge NSArray *)devicesRef;
  gRemoteDevices = [NSMutableArray array];

  printf("[device] found %lu multitouch device(s)\n", (unsigned long)devices.count);

  for (id object in devices) {
    MTDeviceRef device = (__bridge MTDeviceRef)object;
    NSString *summary = DeviceSummary(device);
    bool isRemote = IsSiriRemoteTouchDevice(device);
    printf("[device] %s %s\n", isRemote ? "remote-touch" : "skip", summary.UTF8String);

    if (isRemote) {
      [gRemoteDevices addObject:object];
      MTRegisterContactFrameCallback(device, ContactFrameCallback);
      MTDeviceStart(device, 0);
    }
  }

  if (gRemoteDevices.count == 0) {
    fprintf(stderr, "[error] 没找到 Apple TV 遥控器触摸面。请确认遥控器已通过蓝牙连接到 Mac。\n");
    [NSApp terminate:nil];
    return;
  }

  LogLine("[ready] 正在监听遥控器中间触摸面。日志：%s", kLogFilePath.UTF8String);
  StartRemoteHIDArming();
  StartKarabinerFallbackTimer();
}

static void PrintPermissionHint(void) {
  NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
  Boolean trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);

  LogLine("[permission] accessibility=%s", trusted ? "true" : "false");
  if (!trusted) {
    LogLine("[permission] 辅助功能未开启；将尝试使用 cursor warp 模式移动鼠标。");
  }
}

static int StartListening(void) {
  ResetLogFile();
  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

  PrintPermissionHint();

  dispatch_async(dispatch_get_main_queue(), ^{
    RegisterDevices();
  });

  [NSApp run];
  return 0;
}

static bool RunMoveTest(void) {
  CGPoint before = CurrentMousePosition();
  MoveMouseBy((MouseDelta){20, 0});
  usleep(100000);
  CGPoint after = CurrentMousePosition();
  MoveMouseBy((MouseDelta){-20, 0});

  double movedX = after.x - before.x;
  if (fabs(movedX) < 10.0) {
    fprintf(stderr, "[move-test] failed: before=(%.1f, %.1f) after=(%.1f, %.1f)\n",
            before.x,
            before.y,
            after.x,
            after.y);
    return false;
  }

  printf("[move-test] passed: before=(%.1f, %.1f) after=(%.1f, %.1f)\n",
         before.x,
         before.y,
         after.x,
         after.y);
  return true;
}

static void PrintUsage(const char *programName) {
  printf("Usage: %s [--self-test] [--move-test] [--no-fallback] [--unsafe-karabiner-fallback]\n", programName);
  printf("  --no-fallback                只使用设备级直连监听，绝不读取 Karabiner 多点触控变量。\n");
  printf("  --unsafe-karabiner-fallback  恢复旧备用模式：会影响普通触控板，不建议日常使用。\n");
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    for (int i = 1; i < argc; i++) {
      if (strcmp(argv[i], "--self-test") == 0) {
        return RunSelfTest() ? 0 : 1;
      }
      if (strcmp(argv[i], "--move-test") == 0) {
        return RunMoveTest() ? 0 : 1;
      }
      if (strcmp(argv[i], "--no-fallback") == 0) {
        gEnableKarabinerFallback = false;
        continue;
      }
      if (strcmp(argv[i], "--unsafe-karabiner-fallback") == 0) {
        gEnableKarabinerFallback = true;
        gUnsafeKarabinerFallback = true;
        continue;
      }
      if (strcmp(argv[i], "--help") == 0) {
        PrintUsage(argv[0]);
        return 0;
      }

      fprintf(stderr, "[error] unknown option: %s\n", argv[i]);
      PrintUsage(argv[0]);
      return 2;
    }

    return StartListening();
  }
}
