//
//  SentryClient.m
//  Sentry
//
//  Created by Daniel Griesser on 02/05/2017.
//  Copyright © 2017 Sentry. All rights reserved.
//

#if __has_include(<KSCrash/KSCrash.h>)
#import <KSCrash/KSCrash.h>
#endif

#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryClient.h>
#import <Sentry/SentryLog.h>
#import <Sentry/SentryDsn.h>
#import <Sentry/SentryError.h>
#import <Sentry/SentryQueueableRequestManager.h>
#else
#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryQueueableRequestManager.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryClientVersionString = @"3.0.0";
NSString *const SentryServerVersionString = @"7";

static SentryClient *sharedClient = nil;
static SentryLogLevel logLevel = kError;

@interface SentryClient ()

@property(nonatomic, retain) SentryDsn *dsn;
@property(nonatomic, retain) id<SentryRequestManager> requestManager;

@end

@implementation SentryClient

@dynamic logLevel;

#pragma mark Initializer

- (instancetype)initWithDsn:(NSString *)dsn
           didFailWithError:(NSError *_Nullable *_Nullable)error {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    return [self initWithDsn:dsn
              requestManager:[[SentryQueueableRequestManager alloc] initWithSession:session]
            didFailWithError:error];
}

- (instancetype)initWithDsn:(NSString *)dsn
             requestManager:(id<SentryRequestManager>)requestManager
           didFailWithError:(NSError *__autoreleasing  _Nullable *)error {
    self = [super init];
    if (self) {
        self.dsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];
        if (nil != error) {
            [SentryLog logWithMessage:(*error).localizedDescription andLevel:kError];
            return nil;
        }
        self.requestManager = requestManager;
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Started -- Version: %@", self.class.versionString] andLevel:kDebug];
    }
    return self;
}

#pragma mark Static Getter/Setter

+ (instancetype)sharedClient {
    return sharedClient;
}

+ (void)setSharedClient:(SentryClient *)client {
    sharedClient = client;
}

+ (NSString *)versionString {
    return [NSString stringWithFormat:@"%@ (%@)", SentryClientVersionString, SentryServerVersionString];
}

+ (void)setLogLevel:(SentryLogLevel)level {
    logLevel = level;
}

+ (SentryLogLevel)logLevel {
    return logLevel;
}

#pragma mark Event

- (void)sendEventWithCompletionHandler:(_Nullable SentryQueueableRequestManagerHandler)completionHandler {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"https://sentry.io"]];
    [self.requestManager addRequest:request completionHandler:^(NSError * _Nullable error) {
        NSLog(@"called finish!!!!!");
        if (completionHandler) completionHandler(error);
    }];
}

#if __has_include(<KSCrash/KSCrash.h>)
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    // TODO add kscrash version
    [SentryLog logWithMessage:[NSString stringWithFormat:@"KSCrashHandler started"] andLevel:kDebug];
    [[KSCrash sharedInstance] install];
    return YES;
}
#else
- (BOOL)startCrashHandlerWithError:(NSError *_Nullable *_Nullable)error {
    NSString *message = @"KSCrashHandler not started - Make sure you added KSCrash as a dependency";
    [SentryLog logWithMessage:message andLevel:kError];
    if (nil != error) {
        *error = NSErrorFromSentryError(kKSCrashNotInstalledError, message);
    }
    return NO;
}
#endif

@end

NS_ASSUME_NONNULL_END
