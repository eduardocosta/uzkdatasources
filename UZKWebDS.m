//
//  PKDXWebDS.m
//  Pokedex
//
//  Created by Tiago Furlanetto on 9/15/13.
//  Copyright (c) 2013 Tiago Furlanetto. All rights reserved.
//

#import "UZKWebDS.h"

#import "UICollectionViewCell+CustomObject.h"

@implementation UZKWebDS
{
    NSMutableArray * pages;
    BOOL finished;
    BOOL loading;
    UIRefreshControl * refreshControl;
}

- (id)init
{
    self = [super init];
    
    if ( self )
    {
        self.cellIdentifier = @"Cell";
        pages = [NSMutableArray new];
    }
    
    return self;
}

#pragma mark Gambizarra

- (void)setCollectionView:(UICollectionView *)collectionView
{
    _collectionView = collectionView;
    
    [_collectionView registerNib:[UINib nibWithNibName:@"UZKWebDSLoadMoreCell" bundle:nil] forCellWithReuseIdentifier:@"UZKWebDSLoadMoreCell"];
    
    [_collectionView registerNib:[UINib nibWithNibName:@"UZKWebDSLoadMoreCell" bundle:nil] forCellWithReuseIdentifier:@"UZKWebDSNoResultsCell"];
}

#pragma mark COLLECTION

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [pages count] + (([pages count] && finished) ? 0 : 1);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (section == [pages count]) {
        return 2;
    }
    
    return [[pages objectAtIndex:section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (![pages count] && finished) {
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"UZKWebDSNoResultsCell" forIndexPath:indexPath];
    }
    
    if (indexPath.section == [pages count]) {
        // Posterga o "load", para evitar condições de corrida ao "fritar a tela" que travavam a carga da próxima página
        [self performSelectorOnMainThread:@selector(loadLookPage:) withObject:@([pages count]) waitUntilDone:NO];
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"UZKWebDSLoadMoreCell" forIndexPath:indexPath];
    }
    
    UICollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.customObject = [[pages objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    return cell;
}

#pragma mark Async loading

- (void)loadLookPage:(NSNumber *)n
{
    if (loading) return;
    loading = YES;
    
    int number = [n intValue];
    
    void(^successBlock)(NSArray * look) = ^(NSArray * look)
    {
        [refreshControl endRefreshing];
        
        if (![look count] && number == 0) {
            // Primeira página sem resultados
            finished = YES;
            [self performSelectorOnMainThread:@selector(animateNothingReallyPage)
                                   withObject:nil
                                waitUntilDone:NO];
        } else if (![look count]) {
            // Última página
            finished = YES;
            [self performSelectorOnMainThread:@selector(animateLastPage)
                                   withObject:nil
                                waitUntilDone:NO];
        } else {
            [pages addObject:look];
            [self performSelectorOnMainThread:@selector(animatePageInsertion:)
                                   withObject:n
                                waitUntilDone:NO];
        }
        
        loading = NO;
    };

    [self.client requestPage:number + 1
              withParameters:@{@"limit" : @(20)}
                successBlock:successBlock];
}

#pragma mark Animating Insertions

- (void)animatePageInsertion:(NSNumber *)page
{
    [self updateCollectionAnimator];
    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[page integerValue]]];
}

- (void)animateLastPage
{
    [self updateCollectionAnimator];
    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[pages count]]];
}

- (void)animateNothingReallyPage
{
    [self updateCollectionAnimator];
    [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
}

- (void)updateCollectionAnimator
{
    if ( [self.collectionView.collectionViewLayout respondsToSelector:@selector(updateAnimator)] )
    {
        [self.collectionView.collectionViewLayout performSelector:@selector(updateAnimator)];
    }
}

@end