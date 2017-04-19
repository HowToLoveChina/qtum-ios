//
//  WalletManager.m
//  qtum wallet
//
//  Created by Sharaev Vladimir on 14.12.16.
//  Copyright © 2016 Designsters. All rights reserved.
//

#import "WalletManager.h"
#import "FXKeychain.h"
#import "RPCRequestManager.h"

NSString const *kWalletKey = @"qtum_wallet_wallets_keys";
NSString const *kUserPin = @"PIN";

@interface WalletManager () <WalletDelegate>

@property (nonatomic, strong) NSMutableArray *wallets;
@property (nonatomic, strong) NSString* PIN;
@property (nonatomic, strong) dispatch_group_t registerGroup;

@end

@implementation WalletManager

+ (instancetype)sharedInstance
{
    static WalletManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super alloc] initUniqueInstance];
    });
    return instance;
}

- (instancetype)initUniqueInstance {
    self = [super init];
    if (self != nil) {
        [self load];
    }
    return self;
}

#pragma mark - Lazy Getters

-(NSMutableArray*)wallets {
    
    if (!_wallets) {
        _wallets = @[].mutableCopy;
    }
    return _wallets;
}

#pragma mark - Public Methods

- (void)createNewWalletWithName:(NSString *)name pin:(NSString *)pin withSuccessHandler:(void(^)(Wallet *newWallet))success andFailureHandler:(void(^)())failure {
        
    Wallet *newWallet = [[WalletsFactory sharedInstance] createNewWalletWithName:name pin:pin];
    newWallet.delegate = self;
    
    __weak typeof(self) weakSelf = self;
    [self registerWalletInNode:newWallet withSuccessHandler:^{
        [weakSelf.wallets addObject:newWallet];
        [weakSelf save];
        success(newWallet);
    } andFailureHandler:^{
        failure();
    }];
}

- (void)importWalletWithName:(NSString *)name
                         pin:(NSString *)pin
                   seedWords:(NSArray *)seedWords
          withSuccessHandler:(void(^)(Wallet *newWallet))success
           andFailureHandler:(void(^)())failure {
    
    Wallet *newWallet = [[WalletsFactory sharedInstance] createNewWalletWithName:name pin:pin seedWords:seedWords];
    
    if (!newWallet){
        failure();
        return;
    }
    newWallet.delegate = self;
    
    __weak typeof(self) weakSelf = self;
    [self registerWalletInNode:newWallet withSuccessHandler:^{
        [weakSelf.wallets addObject:newWallet];
        [weakSelf save];
        success(newWallet);
    } andFailureHandler:^{
        failure();
    }];
}

- (Wallet *)getCurrentWallet {
    
    return [self.wallets lastObject];
}

- (void)removeWallet:(Wallet *)wallet {
    
    [self.wallets removeObject:wallet];
    [self save];
}

- (NSArray *)getAllWallets {
    
    return [NSArray arrayWithArray:self.wallets];
}

- (BOOL)haveWallets {
    
    return self.wallets.count != 0;
}

- (void)removeAllWallets {
    
    [self.wallets removeAllObjects];
}

-(void)clear{
    
    [self removePin];
    [self removeAllWallets];
    [self save];
}

#pragma mark - Private methods

- (void)registerWalletInNode:(Wallet *)wallet withSuccessHandler:(void(^)())success andFailureHandler:(void(^)())failure
{
    self.registerGroup = dispatch_group_create();
    
    __block BOOL isAllCompleted = YES;


    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < wallet.countOfUsedKeys; i++) {
        BTCKey *key = [wallet getKeyAtIndex:i];
        
        dispatch_group_enter(self.registerGroup);
        
        NSString* keyString = [AppSettings sharedInstance].isMainNet ? key.address.string : key.addressTestnet.string;
        NSLog(@"Enter -- > %@",keyString);

        [[ApplicationCoordinator sharedInstance].requestManager registerKey:keyString identifier:wallet.getWorldsString new:YES withSuccessHandler:^(id responseObject) {
            dispatch_group_leave(weakSelf.registerGroup);
            NSLog(@"Success");
        } andFailureHandler:^(NSError *error, NSString *message) {
            isAllCompleted = NO;
            dispatch_group_leave(weakSelf.registerGroup);
            NSLog(@"Fail");
        }];
    }
    
    dispatch_group_notify(self.registerGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"All comleted");
            if (isAllCompleted) {
                success();
            }else {
                failure();
            }
        });
    });
}


#pragma mark - WalletDelegate

- (void)walletDidChange:(id)wallet{
    [self save];
}

#pragma mark - KeyChain

- (BOOL)save {
    
    BOOL isSavedWallets = [[FXKeychain defaultKeychain] setObject:self.wallets forKey:kWalletKey];
    return isSavedWallets;
}

- (void)load {
    
    NSMutableArray *savedWallets = [[[FXKeychain defaultKeychain] objectForKey:kWalletKey] mutableCopy];

    for (Wallet *wallet in savedWallets) {
        wallet.delegate = self;
    }

    self.wallets = savedWallets;
    self.PIN = [[FXKeychain defaultKeychain] objectForKey:kUserPin];
}

-(void)storePin:(NSString*) pin {
    
    if ([[FXKeychain defaultKeychain] objectForKey:kUserPin]) {
        [[FXKeychain defaultKeychain] removeObjectForKey:kUserPin];
    }
    [[FXKeychain defaultKeychain] setObject:pin forKey:kUserPin];
    self.PIN = pin;
}

- (void)removePin {
    
    [[FXKeychain defaultKeychain] removeObjectForKey:kUserPin];
    self.PIN = nil;
}

#pragma mark - Token

-(void)updateSpendableObject:(id <Spendable>) object{
    
}

-(void)updateBalanceOfSpendableObject:(id <Spendable>) object{
    
}

-(void)updateHistoryOfSpendableObject:(id <Spendable>) object{
    
}

-(void)loadSpendableObjects{
    [self load];
}

-(void)saveSpendableObjects{
    [self save];
}

-(void)updateSpendableWithObject:(id) updateObject {
    
}

#pragma mark - Addresses Observing

-(void)startObservingForSpendable{
    
    [[ApplicationCoordinator sharedInstance].requestManager startObservingAdresses:[[self getCurrentWallet] getAllKeysAdreeses]];
}

-(void)stopObservingForSpendable{
    
    [[ApplicationCoordinator sharedInstance].requestManager stopObservingAdresses:nil];
}

@end
