// Copyright 2004-present Facebook. All Rights Reserved.

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#include "RCTJSCHelpers.h"

#import <Foundation/Foundation.h>

#import <React/RCTBridge+Private.h>
#import <React/RCTCxxUtils.h>
#import <React/RCTLog.h>
#import <cxxreact/Platform.h>
#import <jschelpers/Value.h>

#if RCT_PROFILE
#import <React/RCTProfile.h>
#endif
using namespace facebook::react;

#if RCT_PROFILE
extern "C" {
  void wixJSProfileBeginSection(uint64_t tag, const char *name, size_t numArgs, systrace_arg_t *args);
  void wixProfileEndSection(uint64_t tag, size_t numArgs, systrace_arg_t *args);
  void wixJSProfileBeginAsyncSection(__unused uint64_t tag, const char *name, int cookie, size_t numArgs, systrace_arg_t *args);
  void wixJSProfileEndAsyncSection(uint64_t tag, const char *name, int cookie, size_t numArgs, systrace_arg_t *args);
}
#endif

namespace {

JSValueRef nativeLoggingHook(
    JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
    const JSValueRef arguments[], JSValueRef *exception) {
  RCTLogLevel level = RCTLogLevelInfo;
  if (argumentCount > 1) {
    level = MAX(level, (RCTLogLevel)Value(ctx, arguments[1]).asNumber());
  }
  if (argumentCount > 0) {
    JSContext *contextObj = contextForGlobalContextRef(JSC_JSContextGetGlobalContext(ctx));
    JSValue *msg = [JSC_JSValue(ctx) valueWithJSValueRef:arguments[0] inContext:contextObj];
    _RCTLogJavaScriptInternal(level, [msg toString]);
  }
  return Value::makeUndefined(ctx);
}

JSValueRef nativePerformanceNow(
    JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
    const JSValueRef arguments[], JSValueRef *exception) {
  return Value::makeNumber(ctx, CACurrentMediaTime() * 1000);
}
  
  JSValueRef nativeTraceBeginAsyncFlowHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceBeginLegacyHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceEndLegacyHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceBeginSectionHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
#if RCT_PROFILE
    JSStringRef arg1 = JSC_JSStringRetain(ctx,JSC_JSValueToStringCopy(ctx, arguments[1], nullptr));
    NSString* module = (__bridge NSString*)JSC_JSStringCopyCFString(ctx, NULL, arg1);
    
    wixJSProfileBeginSection(0, [module UTF8String], 0, 0);
    
    JSC_JSStringRelease(ctx,arg1);
#endif
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceEndSectionHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
#if RCT_PROFILE    
    wixProfileEndSection(0, 0, 0);
#endif
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceBeginAsyncSectionHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
#if RCT_PROFILE
    JSStringRef arg1 = JSC_JSStringRetain(ctx,JSC_JSValueToStringCopy(ctx, arguments[1], nullptr));
    NSString* module = (__bridge NSString*)JSC_JSStringCopyCFString(ctx, NULL, arg1);
    int cookie = (int)JSC_JSValueToNumber(ctx, arguments[2], nullptr);

    wixJSProfileBeginAsyncSection(0, [module UTF8String], cookie, 0, 0);

    JSC_JSStringRelease(ctx,arg1);
#endif
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceEndAsyncSectionHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
#if RCT_PROFILE
    int cookie = (int)JSC_JSValueToNumber(ctx, arguments[2], nullptr);
    wixJSProfileEndAsyncSection(0, 0, cookie, 0, 0);
#endif
    return Value::makeUndefined(ctx);
  }
  
  JSValueRef nativeTraceCounterHook(
                                           JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
                                           const JSValueRef arguments[], JSValueRef *exception) {
    return Value::makeUndefined(ctx);
  }

}

void RCTPrepareJSCExecutor() {
  ReactMarker::logTaggedMarker = [](const ReactMarker::ReactMarkerId, const char *tag) {};
  JSCNativeHooks::loggingHook = nativeLoggingHook;
  JSCNativeHooks::nowHook = nativePerformanceNow;
  JSCNativeHooks::installPerfHooks = RCTFBQuickPerformanceLoggerConfigureHooks;

  JSCNativeHooks::nativeTraceBeginAsyncFlowHook = nativeTraceBeginAsyncFlowHook;
  JSCNativeHooks::nativeTraceBeginLegacyHook = nativeTraceBeginLegacyHook;
  JSCNativeHooks::nativeTraceEndLegacyHook = nativeTraceEndLegacyHook;
  JSCNativeHooks::nativeTraceBeginSectionHook = nativeTraceBeginSectionHook;
  JSCNativeHooks::nativeTraceEndSectionHook = nativeTraceEndSectionHook;
  JSCNativeHooks::nativeTraceBeginAsyncSectionHook = nativeTraceBeginAsyncSectionHook;
  JSCNativeHooks::nativeTraceEndAsyncSectionHook = nativeTraceEndAsyncSectionHook;
  JSCNativeHooks::nativeTraceCounterHook = nativeTraceCounterHook;
}
