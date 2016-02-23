//
//  EidosAppDelegate.m
//  EidosScribe
//
//  Created by Ben Haller on 4/7/15.
//  Copyright (c) 2015-2016 Philipp Messer.  All rights reserved.
//	A product of the Messer Lab, http://messerlab.org/software/
//

//	This file is part of Eidos.
//
//	Eidos is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//	Eidos is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License along with Eidos.  If not, see <http://www.gnu.org/licenses/>.


#import "EidosAppDelegate.h"
#import "EidosTextView.h"
#import "EidosValueWrapper.h"
#import "EidosConsoleWindowController.h"
#import "EidosConsoleWindowControllerDelegate.h"
#import "EidosHelpController.h"

#include "eidos_global.h"
#include "eidos_test.h"

#include <stdexcept>


@interface EidosAppDelegate () <NSApplicationDelegate, EidosConsoleWindowControllerDelegate>
{
	// About window outlets associated with EidosAboutWindow.xib
	IBOutlet NSWindow *aboutWindow;
	IBOutlet NSTextField *aboutVersionTextField;
}
@end


@implementation EidosAppDelegate

- (void)dealloc
{
	// Ask the console controller to forget us as its delegate, to avoid a stale pointer
	[_consoleController setDelegate:nil];
	
	[self setConsoleController:nil];
	
	[super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// Warm up our back end before anything else happens
	Eidos_WarmUp();
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Load our console window nib; we are set up as the delegate in the nib
	[[NSBundle mainBundle] loadNibNamed:@"EidosConsoleWindow" owner:self topLevelObjects:NULL];
	
	// Make the console window visible
	[_consoleController showWindow];
}


//
//	Actions
//
#pragma mark -
#pragma mark Actions

- (IBAction)showAboutWindow:(id)sender
{
	[[NSBundle mainBundle] loadNibNamed:@"EidosAboutWindow" owner:self topLevelObjects:NULL];
	
	// The window is the top-level object in this nib.  It will release itself when closed, so we will retain it on its behalf here.
	// Note that the aboutWindow and aboutWebView outlets do not get zeroed out when the about window closes; but we only use them here.
	// This is not very clean programming practice – just a quick and dirty hack – so don't emulate this code.  :->
	[aboutWindow retain];
	
	// Set our version number string
	NSString *bundleVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *versionString = [NSString stringWithFormat:@"%@ (build %@)", bundleVersionString, bundleVersion];
	
	[aboutVersionTextField setStringValue:versionString];
	
	// Now that everything is set up, show the window
	[aboutWindow makeKeyAndOrderFront:nil];
}

- (IBAction)sendFeedback:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:philipp.messer@gmail.com?subject=Eidos%20Feedback"]];
}

- (IBAction)showMesserLab:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://messerlab.org/"]];
}

- (IBAction)showBenHaller:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.benhaller.com/"]];
}

- (IBAction)showStickSoftware:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sticksoftware.com/"]];
}

- (IBAction)showHelp:(id)sender
{
	[[EidosHelpController sharedController] showWindow];
}


//
//	EidosConsoleWindowControllerDelegate methods
//
#pragma mark -
#pragma mark EidosConsoleWindowControllerDelegate

- (void)eidosConsoleWindowControllerAppendWelcomeMessageAddendum:(EidosConsoleWindowController *)eidosConsoleController
{
	// EidosScribe runs the standard Eidos test suite on launch if the option key is down.
	// You would probably not want to do this in your own Context.
	if ([NSEvent modifierFlags] & NSAlternateKeyMask)
		RunEidosTests();
}

- (void)eidosConsoleWindowControllerConsoleWindowWillClose:(EidosConsoleWindowController *)eidosConsoleController
{
	// EidosScribe quits when its console window is closed, but that
	// behavior is not in any way required or expected.
	[[NSApplication sharedApplication] terminate:nil];
}

- (const std::vector<const EidosMethodSignature*> *)eidosConsoleWindowControllerAllMethodSignatures:(EidosConsoleWindowController *)eidosConsoleController
{
	// Most of the time, the Context will have classes defined with Eidos methods, and those would need to be returned here.
	// Since EidosScribe is a very simple Context that defines no object classes, it has nothing to provide here.
	return nullptr;
}

@end



































































