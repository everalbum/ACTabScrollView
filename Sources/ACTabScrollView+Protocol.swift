//
//  ACTabScrollView+Protocol.swift
//  ACTabScrollView
//
//  Created by AzureChen on 2016/4/21.
//  Copyright © 2016年 AzureChen. All rights reserved.
//

import UIKit

public protocol ACTabScrollViewDelegate {
    
    // determine the frame of the contentScrollView
    func tabScrollViewContentViewFrameFillsViewBounds() -> Bool
    
    // determine the insets for the frame of the tabSectionScrollView
    func tabSectionScrollViewFrameInset() -> UIEdgeInsets
    
    // triggered by starting scrolling
    func tabScrollViewDidStartScrolling(_ tabScrollView: ACTabScrollView)
    
    // triggered by starting scrolling
    func tabScrollViewEndStartScrolling(_ tabScrollView: ACTabScrollView)
    
    // triggered by stopping at particular page
    func tabScrollView(_ tabScrollView: ACTabScrollView, didChangePageTo index: Int)
    
    // triggered by scrolling through any pages
    func tabScrollView(_ tabScrollView: ACTabScrollView, didScrollPageTo index: Int)
}

public protocol ACTabScrollViewDataSource {
    
    // get pages count
    func numberOfPagesInTabScrollView(_ tabScrollView: ACTabScrollView) -> Int
    
    // get the tab at index
    func tabScrollView(_ tabScrollView: ACTabScrollView, tabViewForPageAtIndex index: Int) -> UIView
    
    // get the content at index
    func tabScrollView(_ tabScrollView: ACTabScrollView, contentViewForPageAtIndex index: Int) -> UIView
}
