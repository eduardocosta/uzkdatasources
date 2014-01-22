//
//  PKDXWebDS.m
//  Pokedex
//
//  Created by Tiago Furlanetto on 9/15/13.
//  Copyright (c) 2013 Tiago Furlanetto. All rights reserved.
//

#import "UZKWebDS.h"

#import "UICollectionViewCell+CustomObject.h"
#import "UITableViewCell+CustomObject.h"

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
    
    [_collectionView registerNib:[UINib nibWithNibName:@"UZKWebDSLoadMoreCollectionCell" bundle:nil] forCellWithReuseIdentifier:@"UZKWebDSLoadMoreCollectionCell"];
    
    [_collectionView registerNib:[UINib nibWithNibName:@"UZKWebDSNoResultsCollectionCell" bundle:nil] forCellWithReuseIdentifier:@"UZKWebDSNoResultsCollectionCell"];
}

- (void)setTableView:(UITableView *)tableView
{
    _tableView = tableView;
    
    [_tableView registerNib:[UINib nibWithNibName:@"UZKWebDSLoadMoreTableCell" bundle:nil] forCellReuseIdentifier:@"UZKWebDSLoadMoreTableCell"];
    
    [_tableView registerNib:[UINib nibWithNibName:@"UZKWebDSNoResultsTableCell" bundle:nil] forCellReuseIdentifier:@"UZKWebDSNoResultsTableCell"];
}


#pragma mark Initial Stuff

- (void)setSectionData:(NSArray *)dataForSection0, ... NS_REQUIRES_NIL_TERMINATION
{
    [self resetData];
    
    va_list args;
    va_start(args, dataForSection0);
    for (NSArray * dataForSection = dataForSection0; dataForSection != nil; dataForSection = va_arg(args, NSArray *))
    {
        [pages addObject:dataForSection];
    }
    va_end(args);
}


#pragma mark COLLECTION

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [pages count] + (([pages count] && finished) ? 0 : 1);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (section == [pages count]) {
        return 1;
    }
    
    return [[pages objectAtIndex:section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (![pages count] && finished) {
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"UZKWebDSNoResultsCollectionCell" forIndexPath:indexPath];
    }
    
    if (indexPath.section - self.sectionIndexOffset >= [pages count]) {
        // Posterga o "load", para evitar condições de corrida ao "fritar a tela" que travavam a carga da próxima página
        [self performSelectorOnMainThread:@selector(loadPage:) withObject:@([pages count]) waitUntilDone:NO];
        return [collectionView dequeueReusableCellWithReuseIdentifier:@"UZKWebDSLoadMoreCollectionCell" forIndexPath:indexPath];
    }
    
    id customObject = [self objectForIndexPath:indexPath];
    NSString * cellIdentifier;
    
    if ( self.cellIdentifierBlock )
    {
        cellIdentifier = self.cellIdentifierBlock(customObject);
    }
    
    if ( !cellIdentifier ) //previous block can return nil
    {
        cellIdentifier = self.cellIdentifier;
    }
    
    UICollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    
    cell.customObject = customObject;
    
    if ( self.cellDequeueBlock )
    {
        self.cellDequeueBlock(cell);
    }
    
    return cell;
}


#pragma mark TABLE

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [pages count] + (([pages count] && finished) ? 0 : 1);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == [pages count]) {
        return 1;
    }
    
    return [[pages objectAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![pages count] && finished) {
        return [tableView dequeueReusableCellWithIdentifier:@"UZKWebDSNoResultsTableCell" forIndexPath:indexPath];
    }
    
    if (indexPath.section - self.sectionIndexOffset >= [pages count]) {
        // Posterga o "load", para evitar condições de corrida ao "fritar a tela" que travavam a carga da próxima página
        [self performSelectorOnMainThread:@selector(loadPage:) withObject:@([pages count]) waitUntilDone:NO];
        return [tableView dequeueReusableCellWithIdentifier:@"UZKWebDSLoadMoreTableCell" forIndexPath:indexPath];
    }
    
    id customObject = [self objectForIndexPath:indexPath];
    NSString * cellIdentifier;
    
    if ( self.cellIdentifierBlock )
    {
        cellIdentifier = self.cellIdentifierBlock(customObject);
    }
    
    if ( !cellIdentifier ) //previous block can return nil
    {
        cellIdentifier = self.cellIdentifier;
    }
    
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    cell.customObject = customObject;
    
    if ( self.cellDequeueBlock )
    {
        self.cellDequeueBlock(cell);
    }
    
    return cell;
}


#pragma mark Custom Object Management

- (id)objectForIndexPath:(NSIndexPath *)indexPath
{
    return [[pages objectAtIndex:indexPath.section - self.sectionIndexOffset] objectAtIndex:indexPath.row];
}


#pragma mark Async loading

- (void)loadPage:(NSNumber *)n
{
    if (loading) return;
    loading = YES;
    
    int number = [n intValue];
    
    void(^successBlock)(NSArray * stuff) = ^(NSArray * stuff)
    {
        [refreshControl endRefreshing];
        
        if (![stuff count] && number == 0) {
            // Primeira página sem resultados
            finished = YES;
            [self performSelectorOnMainThread:@selector(animateNothingReallyPage)
                                   withObject:nil
                                waitUntilDone:NO];
        } else if (![stuff count]) {
            // Última página
            finished = YES;
            [self performSelectorOnMainThread:@selector(animateLastPage)
                                   withObject:nil
                                waitUntilDone:NO];
        } else {
            [pages addObject:stuff];
            [self performSelectorOnMainThread:@selector(animatePageInsertion:)
                                   withObject:n
                                waitUntilDone:NO];
        }
        
        loading = NO;
    };

    [self.client requestPage:number + 1
              withParameters:self.parameters
                successBlock:successBlock];
}

#pragma mark Animating Insertions

- (void)animatePageInsertion:(NSNumber *)page
{
    [self updateCollectionAnimator];
    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[page integerValue] + self.sectionIndexOffset]];
    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:[page integerValue] + self.sectionIndexOffset] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)animateLastPage
{
    [self updateCollectionAnimator];
    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[pages count] + self.sectionIndexOffset]];
    [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:[pages count] + self.sectionIndexOffset] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)animateNothingReallyPage
{
    [self updateCollectionAnimator];
    [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0 + self.sectionIndexOffset]];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0 + self.sectionIndexOffset] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateCollectionAnimator
{
    if ( [self.collectionView.collectionViewLayout respondsToSelector:@selector(updateAnimator)] )
    {
        [self.collectionView.collectionViewLayout performSelector:@selector(updateAnimator)];
    }
}


#pragma mark Start All Over

- (void)resetData
{
    pages = [NSMutableArray new];
    finished = NO;
    loading = NO;
}

@end
