/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RCTBridge.h"
#import "RCTBridge+Private.h"

#import <objc/runtime.h>

#import "RCTConvert.h"
#import "RCTEventDispatcher.h"
#if RCT_ENABLE_INSPECTOR
#import "RCTInspectorDevServerHelper.h"
#endif
#import "RCTLog.h"
#import "RCTModuleData.h"
#import "RCTPerformanceLogger.h"
#import "RCTProfile.h"
#import "RCTReloadCommand.h"
#import "RCTUtils.h"

#import <dlfcn.h>

NSString *const RCTJavaScriptWillStartLoadingNotification = @"RCTJavaScriptWillStartLoadingNotification";
NSString *const RCTJavaScriptWillStartExecutingNotification = @"RCTJavaScriptWillStartExecutingNotification";
NSString *const RCTJavaScriptDidLoadNotification = @"RCTJavaScriptDidLoadNotification";
NSString *const RCTJavaScriptDidFailToLoadNotification = @"RCTJavaScriptDidFailToLoadNotification";
NSString *const RCTDidInitializeModuleNotification = @"RCTDidInitializeModuleNotification";
NSString *const RCTBridgeWillReloadNotification = @"RCTBridgeWillReloadNotification";
NSString *const RCTBridgeWillDownloadScriptNotification = @"RCTBridgeWillDownloadScriptNotification";
NSString *const RCTBridgeDidDownloadScriptNotification = @"RCTBridgeDidDownloadScriptNotification";
NSString *const RCTBridgeDidDownloadScriptNotificationSourceKey = @"source";
NSString *const RCTBridgeDidDownloadScriptNotificationBridgeDescriptionKey = @"bridgeDescription";

//extern DTXEventIdentifier DTXProfilerMarkEventIntervalBegin(NSString* category, NSString* name, NSString* __nullable additionalInfo);
//extern void DTXProfilerMarkEventIntervalEnd(DTXEventIdentifier identifier, DTXEventStatus eventStatus, NSString* __nullable additionalInfo);
//extern void DTXProfilerMarkEvent(NSString* category, NSString* name, DTXEventStatus eventStatus, NSString* __nullable additionalInfo);

static id (*__DTXProfilerMarkEventIntervalBegin)(NSString* category, NSString* name, NSString* __nullable additionalInfo);
static void (*__DTXProfilerMarkEventIntervalEnd)(id identifier, NSUInteger eventStatus, NSString* __nullable additionalInfo);
static void (*__DTXProfilerMarkEvent)(NSString* category, NSString* name, NSUInteger eventStatus, NSString* __nullable additionalInfo);

__attribute((__constructor__))
static void _setupSymbols(void)
{
  __DTXProfilerMarkEventIntervalBegin = dlsym(RTLD_DEFAULT, "DTXProfilerMarkEventIntervalBegin");
  __DTXProfilerMarkEventIntervalEnd = dlsym(RTLD_DEFAULT, "DTXProfilerMarkEventIntervalEnd");
  __DTXProfilerMarkEvent = dlsym(RTLD_DEFAULT, "DTXProfilerMarkEvent");
}

id __wix_begin_moduleLoad(NSString* className);
id __wix_begin_moduleLoad(NSString* className)
{
  if(className == nil)
  {
    return nil;
  }
  
  if(__DTXProfilerMarkEventIntervalBegin == NULL)
  {
    return nil;
  }
  
  return __DTXProfilerMarkEventIntervalBegin(@"React Native", @"Module Load", className);
}

void __wix_end_event(id eventId);
void __wix_end_event(id eventId)
{
  if(__DTXProfilerMarkEventIntervalEnd == NULL)
  {
    return;
  }
  
  __DTXProfilerMarkEventIntervalEnd(eventId, 0, nil);
}

void* __wix_begin_loadAppString(const char* sourceURL);
void* __wix_begin_loadAppString(const char* sourceURL)
{
  if(__DTXProfilerMarkEventIntervalBegin == NULL)
  {
    return NULL;
  }
  
  id rv = __DTXProfilerMarkEventIntervalBegin(@"React Native", @"loadApplicationString", [NSString stringWithFormat:@"%s", sourceURL]);
  
  return (void*)CFBridgingRetain(rv);
}

void* __wix_begin_loadModule(const char* moduleName);
void* __wix_begin_loadModule(const char* moduleName)
{
  if(__DTXProfilerMarkEventIntervalBegin == NULL)
  {
    return NULL;
  }
  
  id rv = __DTXProfilerMarkEventIntervalBegin(@"React Native", @"loadModule", [NSString stringWithFormat:@"%s", moduleName]);
  
  return (void*)CFBridgingRetain(rv);
}

void* __wix_begin_adoptString(const unsigned long long int stringLength);
void* __wix_begin_adoptString(const unsigned long long int stringLength)
{
  if(__DTXProfilerMarkEventIntervalBegin == NULL)
  {
    return NULL;
  }
  
  id rv = __DTXProfilerMarkEventIntervalBegin(@"React Native", @"adoptString", [NSString stringWithFormat:@"String length: %llu", stringLength]);
  
  return (void*)CFBridgingRetain(rv);
}

void* __wix_begin_JSEvaluateScript(JSStringRef sourceURL);
void* __wix_begin_JSEvaluateScript(JSStringRef sourceURL)
{
  if(__DTXProfilerMarkEventIntervalBegin == NULL)
  {
    return NULL;
  }
  
  NSString* sourceURLString = CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, sourceURL));
  
  id rv = __DTXProfilerMarkEventIntervalBegin(@"React Native", @"JSEvaluateScript", sourceURLString);
  
  return (void*)CFBridgingRetain(rv);
}

void __wix_end_event_c(void* ctx);
void __wix_end_event_c(void* ctx)
{
  if(ctx == NULL)
  {
    return;
  }
  
  id ctxObj = CFBridgingRelease(ctx);
  
  __wix_end_event(ctxObj);
}

void __wix_mark_event_js_callback(JSContextRef ctx, size_t argumentCount, const JSValueRef arguments[]);
void __wix_mark_event_js_callback(JSContextRef ctx, size_t argumentCount, const JSValueRef arguments[])
{
  if(__DTXProfilerMarkEvent == NULL)
  {
    return;
  }
  
  if(argumentCount < 1)
  {
    return;
  }
  
  NSMutableString* argumentsString = [NSMutableString new];
  
  JSStringRef eventNameJS = JSValueToStringCopy(ctx, arguments[0], NULL);
  NSString* eventName = nil;
  
  if(eventNameJS)
  {
    eventName = CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, eventNameJS));
    
    JSStringRelease(eventNameJS);
    eventNameJS = NULL;
  }
  
  if(eventName == nil)
  {
    return;
  }
  
  for(NSUInteger idx = 1; idx < argumentCount; idx++)
  {
    JSStringRef str = JSValueCreateJSONString(ctx, arguments[idx], 4, NULL);
    
    if(str)
    {
      [argumentsString appendFormat:@"%@\n", CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, str))];
      
      JSStringRelease(str);
      str = NULL;
    }
  }
  
  __DTXProfilerMarkEvent(@"React Native", eventName, 0, argumentsString);
}

static NSMutableArray<Class> *RCTModuleClasses;
static dispatch_queue_t RCTModuleClassesSyncQueue;
NSArray<Class> *RCTGetModuleClasses(void)
{
  __block NSArray<Class> *result;
  dispatch_sync(RCTModuleClassesSyncQueue, ^{
    result = [RCTModuleClasses copy];
  });
  return result;
}

void RCTFBQuickPerformanceLoggerConfigureHooks(__unused JSGlobalContextRef ctx) { }

/**
 * Register the given class as a bridge module. All modules must be registered
 * prior to the first bridge initialization.
 */
void RCTRegisterModule(Class);
void RCTRegisterModule(Class moduleClass)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    RCTModuleClasses = [NSMutableArray new];
    RCTModuleClassesSyncQueue = dispatch_queue_create("com.facebook.react.ModuleClassesSyncQueue", DISPATCH_QUEUE_CONCURRENT);
  });

  RCTAssert([moduleClass conformsToProtocol:@protocol(RCTBridgeModule)],
            @"%@ does not conform to the RCTBridgeModule protocol",
            moduleClass);

  // Register module
  dispatch_barrier_async(RCTModuleClassesSyncQueue, ^{
    [RCTModuleClasses addObject:moduleClass];
  });
}

/**
 * This function returns the module name for a given class.
 */
NSString *RCTBridgeModuleNameForClass(Class cls)
{
#if RCT_DEBUG
  RCTAssert([cls conformsToProtocol:@protocol(RCTBridgeModule)],
            @"Bridge module `%@` does not conform to RCTBridgeModule", cls);
#endif

  NSString *name = [cls moduleName];
  if (name.length == 0) {
    name = NSStringFromClass(cls);
  }

  if ([name hasPrefix:@"RK"]) {
    name = [name substringFromIndex:2];
  } else if ([name hasPrefix:@"RCT"]) {
    name = [name substringFromIndex:3];
  }

  return name;
}

#if RCT_DEBUG
void RCTVerifyAllModulesExported(NSArray *extraModules)
{
  // Check for unexported modules
  unsigned int classCount;
  Class *classes = objc_copyClassList(&classCount);

  NSMutableSet *moduleClasses = [NSMutableSet new];
  [moduleClasses addObjectsFromArray:RCTGetModuleClasses()];
  [moduleClasses addObjectsFromArray:[extraModules valueForKeyPath:@"class"]];

  for (unsigned int i = 0; i < classCount; i++) {
    Class cls = classes[i];
    if (strncmp(class_getName(cls), "RCTCxxModule", strlen("RCTCxxModule")) == 0) {
      continue;
    }
    Class superclass = cls;
    while (superclass) {
      if (class_conformsToProtocol(superclass, @protocol(RCTBridgeModule))) {
        if ([moduleClasses containsObject:cls]) {
          break;
        }

        // Verify it's not a super-class of one of our moduleClasses
        BOOL isModuleSuperClass = NO;
        for (Class moduleClass in moduleClasses) {
          if ([moduleClass isSubclassOfClass:cls]) {
            isModuleSuperClass = YES;
            break;
          }
        }
        if (isModuleSuperClass) {
          break;
        }

        RCTLogWarn(@"Class %@ was not exported. Did you forget to use RCT_EXPORT_MODULE()?", cls);
        break;
      }
      superclass = class_getSuperclass(superclass);
    }
  }

  free(classes);
}
#endif

@interface RCTBridge () <RCTReloadListener>
@end

@implementation RCTBridge
{
  NSURL *_delegateBundleURL;
}

dispatch_queue_t RCTJSThread;

+ (void)initialize
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{

    // Set up JS thread
    RCTJSThread = (id)kCFNull;
  });
}

static RCTBridge *RCTCurrentBridgeInstance = nil;

/**
 * The last current active bridge instance. This is set automatically whenever
 * the bridge is accessed. It can be useful for static functions or singletons
 * that need to access the bridge for purposes such as logging, but should not
 * be relied upon to return any particular instance, due to race conditions.
 */
+ (instancetype)currentBridge
{
  return RCTCurrentBridgeInstance;
}

+ (void)setCurrentBridge:(RCTBridge *)currentBridge
{
  RCTCurrentBridgeInstance = currentBridge;
}

- (instancetype)initWithDelegate:(id<RCTBridgeDelegate>)delegate
                   launchOptions:(NSDictionary *)launchOptions
{
  return [self initWithDelegate:delegate
                      bundleURL:nil
                 moduleProvider:nil
                  launchOptions:launchOptions];
}

- (instancetype)initWithBundleURL:(NSURL *)bundleURL
                   moduleProvider:(RCTBridgeModuleListProvider)block
                    launchOptions:(NSDictionary *)launchOptions
{
  return [self initWithDelegate:nil
                      bundleURL:bundleURL
                 moduleProvider:block
                  launchOptions:launchOptions];
}

- (instancetype)initWithDelegate:(id<RCTBridgeDelegate>)delegate
                       bundleURL:(NSURL *)bundleURL
                  moduleProvider:(RCTBridgeModuleListProvider)block
                   launchOptions:(NSDictionary *)launchOptions
{
  if (self = [super init]) {
    _delegate = delegate;
    _bundleURL = bundleURL;
    _moduleProvider = block;
    _launchOptions = [launchOptions copy];

    [self setUp];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (void)dealloc
{
  /**
   * This runs only on the main thread, but crashes the subclass
   * RCTAssertMainQueue();
   */
  [self invalidate];
}

- (void)didReceiveReloadCommand
{
  [self reload];
}

- (NSArray<Class> *)moduleClasses
{
  return self.batchedBridge.moduleClasses;
}

- (id)moduleForName:(NSString *)moduleName
{
  return [self.batchedBridge moduleForName:moduleName];
}

- (id)moduleForClass:(Class)moduleClass
{
  return [self moduleForName:RCTBridgeModuleNameForClass(moduleClass)];
}

- (NSArray *)modulesConformingToProtocol:(Protocol *)protocol
{
  NSMutableArray *modules = [NSMutableArray new];
  for (Class moduleClass in [self.moduleClasses copy]) {
    if ([moduleClass conformsToProtocol:protocol]) {
      id module = [self moduleForClass:moduleClass];
      if (module) {
        [modules addObject:module];
      }
    }
  }
  return [modules copy];
}

- (BOOL)moduleIsInitialized:(Class)moduleClass
{
  return [self.batchedBridge moduleIsInitialized:moduleClass];
}

- (id)jsBoundExtraModuleForClass:(Class)moduleClass
{
  return [self.batchedBridge jsBoundExtraModuleForClass:moduleClass];
}

- (void)reload
{
  #if RCT_ENABLE_INSPECTOR
  // Disable debugger to resume the JsVM & avoid thread locks while reloading
  [RCTInspectorDevServerHelper disableDebugger];
  #endif

  [[NSNotificationCenter defaultCenter] postNotificationName:RCTBridgeWillReloadNotification object:self];

  /**
   * Any thread
   */
  dispatch_async(dispatch_get_main_queue(), ^{
    [self invalidate];
    [self setUp];
  });
}

- (void)requestReload
{
  [self reload];
}

- (Class)bridgeClass
{
  return [RCTCxxBridge class];
}

- (void)setUp
{
  RCT_PROFILE_BEGIN_EVENT(0, @"-[RCTBridge setUp]", nil);

  _performanceLogger = [RCTPerformanceLogger new];
  [_performanceLogger markStartForTag:RCTPLBridgeStartup];
  [_performanceLogger markStartForTag:RCTPLTTI];

  Class bridgeClass = self.bridgeClass;

  #if RCT_DEV
  RCTExecuteOnMainQueue(^{
    RCTRegisterReloadCommandListener(self);
  });
  #endif

  // Only update bundleURL from delegate if delegate bundleURL has changed
  NSURL *previousDelegateURL = _delegateBundleURL;
  _delegateBundleURL = [self.delegate sourceURLForBridge:self];
  if (_delegateBundleURL && ![_delegateBundleURL isEqual:previousDelegateURL]) {
    _bundleURL = _delegateBundleURL;
  }

  // Sanitize the bundle URL
  _bundleURL = [RCTConvert NSURL:_bundleURL.absoluteString];

  self.batchedBridge = [[bridgeClass alloc] initWithParentBridge:self];
  [self.batchedBridge start];

  RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
}

- (BOOL)isLoading
{
  return self.batchedBridge.loading;
}

- (BOOL)isValid
{
  return self.batchedBridge.valid;
}

- (BOOL)isBatchActive
{
  return [_batchedBridge isBatchActive];
}

- (void)invalidate
{
  RCTBridge *batchedBridge = self.batchedBridge;
  self.batchedBridge = nil;

  if (batchedBridge) {
    RCTExecuteOnMainQueue(^{
      [batchedBridge invalidate];
    });
  }
}

- (void)registerAdditionalModuleClasses:(NSArray<Class> *)modules
{
  [self.batchedBridge registerAdditionalModuleClasses:modules];
}

- (void)enqueueJSCall:(NSString *)moduleDotMethod args:(NSArray *)args
{
  NSArray<NSString *> *ids = [moduleDotMethod componentsSeparatedByString:@"."];
  NSString *module = ids[0];
  NSString *method = ids[1];
  [self enqueueJSCall:module method:method args:args completion:NULL];
}

- (void)enqueueJSCall:(NSString *)module method:(NSString *)method args:(NSArray *)args completion:(dispatch_block_t)completion
{
  [self.batchedBridge enqueueJSCall:module method:method args:args completion:completion];
}

- (void)enqueueCallback:(NSNumber *)cbID args:(NSArray *)args
{
  [self.batchedBridge enqueueCallback:cbID args:args];
}

- (void)registerSegmentWithId:(NSUInteger)segmentId path:(NSString *)path
{
  [self.batchedBridge registerSegmentWithId:segmentId path:path];
}

- (JSGlobalContextRef)jsContextRef
{
  return [self.batchedBridge jsContextRef];
}

@end
