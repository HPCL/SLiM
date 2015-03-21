//
//  ScriptMod.h
//  SLiM
//
//  Created by Ben Haller on 3/20/15.
//  Copyright (c) 2015 Philipp Messer.  All rights reserved.
//	A product of the Messer Lab, http://messerlab.org/software/
//

//	This file is part of SLiM.
//
//	SLiM is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//	SLiM is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License along with SLiM.  If not, see <http://www.gnu.org/licenses/>.


#import <Cocoa/Cocoa.h>

#include "SLiMWindowController.h"


@interface ScriptModSubclassViewPlaceholder : NSView
@end


@interface ScriptMod : NSObject
{
	SLiMWindowController *controller;	// not retained
	BOOL validInput;
	BOOL needsRecycle, showingRecycleOption;
	CGFloat recycleWarningConstraintHeight;
}

// Outlets connected to objects in ScriptMod.xib
@property (nonatomic, retain) IBOutlet NSWindow *scriptModSheet;
@property (nonatomic, retain) IBOutlet NSTextField *sheetTitleTextField;
@property (nonatomic, retain) IBOutlet NSTextField *recycleWarning;
@property (nonatomic, retain) IBOutlet NSLayoutConstraint *recycleWarningHeightConstraint;
@property (nonatomic, retain) IBOutlet NSTextField *recycleImageTextField;
@property (nonatomic, retain) IBOutlet NSButton *insertOnlyButton;
@property (nonatomic, retain) IBOutlet NSButton *insertAndExecuteButton;
@property (nonatomic, retain) IBOutlet ScriptModSubclassViewPlaceholder *customViewPlaceholder;

// Outlets connected to objects in the nib supplied by the subclass
@property (nonatomic, retain) IBOutlet NSView *customViewFromSubclass;

// Basic methods, not for overriding
+ (void)runWithController:(SLiMWindowController *)windowController;					// This is the class method called to initiate a ScriptMod action; it handles everything
- (instancetype)initWithController:(SLiMWindowController *)windowController;		// Designated initializer

- (void)loadConfigurationSheet;
- (void)runConfigurationSheet;

- (IBAction)configureSheetInsert:(id)sender;
- (IBAction)configureSheetInsertExecute:(id)sender;
- (IBAction)configureSheetCancel:(id)sender;

// Utility methods for regular expressions, validation, UI configuration, etc. for some common tasks

+ (NSRegularExpression *)regexForInt;
+ (NSRegularExpression *)regexForScriptSectionHead;

+ (BOOL)validIntValueInTextField:(NSTextField *)textfield withMin:(int)minValue max:(int)maxValue;
+ (NSColor *)validationErrorColor;			// use this for elements such as textfields that can set their background color
+ (NSColor *)validationErrorFilterColor;	// use this for elements that must be tinted using CIFilter

- (void)configureSubpopulationPopup:(NSPopUpButton *)button;	// set up a standard popup menu to choose a subpopulation

// These methods are the points where the subclass plugs in to the configuration panel run

- (void)configSheetLoaded;										// the sheet is loaded but not yet shown; subclasses should set values for controls, etc.
- (IBAction)validateControls:(id)sender;						// can be wired to controls that need to trigger validation; subclasses should call super

// These methods can be overridden by subclasses to provide information to the superclass

- (NSString *)sheetTitle;										// the title of the script modification, displayed in a label textfield
- (NSString *)nibName;											// the name of the nib file for the configuration sheet; defaults to the name of the subclass
- (NSString *)scriptSectionName;								// the name of the script section where the new script line will be inserted; defaults to "#DEMOGRAPHY AND STRUCTURE"
- (NSString *)scriptLineWithExecute:(BOOL)executeNow;			// the script string to be inserted, based upon the configuration panel run
- (NSString *)sortingGrepPattern;								// a grep pattern that extracts a number used to determine the right insertion point for the new script line; defaults to a number at the start of the line

@end














































































