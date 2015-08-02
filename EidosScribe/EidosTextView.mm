//
//  EidosTextView.mm
//  EidosScribe
//
//  Created by Ben Haller on 6/14/15.
//  Copyright (c) 2015 Philipp Messer.  All rights reserved.
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


#import "EidosTextView.h"

#include "eidos_script.h"
#include "eidos_call_signature.h"

#include <stdexcept>


using std::vector;
using std::string;


@implementation EidosTextView

// produce standard text attributes including our font (Menlo 11), tab stops (every three spaces), and font colors for syntax coloring
+ (NSDictionary *)consoleTextAttributesWithColor:(NSColor *)textColor
{
	static NSFont *menlo11Font = nil;
	static NSMutableParagraphStyle *paragraphStyle = nil;
	
	if (!menlo11Font)
		menlo11Font = [[NSFont fontWithName:@"Menlo" size:11.0] retain];
	
	if (!paragraphStyle)
	{
		paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
		CGFloat tabInterval = [menlo11Font maximumAdvancement].width * 3;
		NSMutableArray *tabs = [NSMutableArray array];
		
		[paragraphStyle setDefaultTabInterval:tabInterval];
		
		for (int tabStop = 1; tabStop <= 20; ++tabStop)
			[tabs addObject:[[NSTextTab alloc] initWithTextAlignment:NSLeftTextAlignment location:tabInterval * tabStop options:nil]];
		
		[paragraphStyle setTabStops:tabs];
	}
	
	if (textColor)
		return [NSDictionary dictionaryWithObjectsAndKeys:textColor, NSForegroundColorAttributeName, menlo11Font, NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
	else
		return [NSDictionary dictionaryWithObjectsAndKeys:menlo11Font, NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
}

- (void)awakeFromNib
{
	// Turn off all of Cocoa's fancy text editing stuff
	[self setAutomaticDashSubstitutionEnabled:NO];
	[self setAutomaticDataDetectionEnabled:NO];
	[self setAutomaticLinkDetectionEnabled:NO];
	[self setAutomaticQuoteSubstitutionEnabled:NO];
	[self setAutomaticSpellingCorrectionEnabled:NO];
	[self setAutomaticTextReplacementEnabled:NO];
	[self setContinuousSpellCheckingEnabled:NO];
	[self setGrammarCheckingEnabled:NO];
	[self turnOffLigatures:nil];
	
	// Fix the font and typing attributes
	[self setFont:[NSFont fontWithName:@"Menlo" size:11.0]];
	[self setTypingAttributes:[EidosTextView consoleTextAttributesWithColor:nil]];
	
	// Fix text container insets to look a bit nicer; {0,0} by default
	[self setTextContainerInset:NSMakeSize(0.0, 5.0)];
}

// handle autoindent by matching the whitespace beginning the current line
- (void)insertNewline:(id)sender
{
	NSString *textString = [self string];
	NSUInteger selectionStart = [self selectedRange].location;
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSCharacterSet *whitespaceChars = [NSCharacterSet whitespaceCharacterSet];
	
	// start at the start of the selection and move backwards to the beginning of the line
	NSUInteger lineStart = selectionStart;
	
	while (lineStart > 0)
	{
		unichar ch = [textString characterAtIndex:lineStart - 1];
		
		if ([newlineChars characterIsMember:ch])
			break;
		
		--lineStart;
	}
	
	// now we're either at the beginning of the content, or the beginning of the line; now find the end of the whitespace there, up to where we started
	NSUInteger whitespaceEnd = lineStart;
	
	while (whitespaceEnd < selectionStart)
	{
		unichar ch = [textString characterAtIndex:whitespaceEnd];
		
		if (![whitespaceChars characterIsMember:ch])
			break;
		
		++whitespaceEnd;
	}
	
	// now we have the range of the leading whitespace; copy that, call super to insert the newline, and then paste in the whitespace
	NSRange whitespaceRange = NSMakeRange(lineStart, whitespaceEnd - lineStart);
	NSString *whitespaceString = [textString substringWithRange:whitespaceRange];
	
	[super insertNewline:sender];
	[self insertText:whitespaceString];
}

// NSTextView copies only plain text for us, because it is set to have rich text turned off.  That setting only means it is turned off for the user; the
// user can't change the font, size, etc.  But we still can, and do, programatically to do our syntax formatting.  We want that style information to get
// copied to the pasteboard, and as far as I can tell this subclass is necessary to make it happen.  Seems kind of lame.
- (IBAction)copy:(id)sender
{
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSAttributedString *attrString = [self textStorage];
	NSRange selectedRange = [self selectedRange];
	NSAttributedString *attrStringInRange = [attrString attributedSubstringFromRange:selectedRange];
	
	// The documentation sucks, but as far as I can tell, this puts both a plain-text and a rich-text representation on the pasteboard
	[pasteboard clearContents];
	[pasteboard writeObjects:[NSArray arrayWithObject:attrStringInRange]];
}

- (IBAction)shiftSelectionLeft:(id)sender
{
	if ([self isEditable])
	{
		NSTextStorage *ts = [self textStorage];
		NSMutableString *scriptString = [[self string] mutableCopy];
		int scriptLength = (int)[scriptString length];
		NSRange selectedRange = [self selectedRange];
		NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
		NSUInteger scanPosition;
		
		// start at the start of the selection and scan backwards over non-newline text until we hit a newline or the start of the file
		scanPosition = selectedRange.location;
		
		while (scanPosition > 0)
		{
			if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition - 1]])
				break;
			
			--scanPosition;
		}
		
		// ok, we're at the start of the line that the selection starts on; start removing tabs
		[ts beginEditing];
		
		while ((scanPosition == selectedRange.location) || (scanPosition < selectedRange.location + selectedRange.length))
		{
			// if we are at the very end of the script string, then we have hit the end and we're done
			if (scanPosition == scriptLength)
				break;
			
			// insert a tab at the start of this line and adjust our selection
			if ([scriptString characterAtIndex:scanPosition] == '\t')
			{
				[ts replaceCharactersInRange:NSMakeRange(scanPosition, 1) withString:@""];
				[scriptString replaceCharactersInRange:NSMakeRange(scanPosition, 1) withString:@""];
				scriptLength--;
				
				if (scanPosition < selectedRange.location)
					selectedRange.location--;
				else
					if (selectedRange.length > 0)
						selectedRange.length--;
			}
			
			// now scan forward to the end of this line
			while (scanPosition < scriptLength)
			{
				if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// and then scan forward to the beginning of the next line
			while (scanPosition < scriptLength)
			{
				if (![newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
		}
		
		[ts endEditing];
		[self setSelectedRange:selectedRange];
	}
	else
	{
		NSBeep();
	}
}

- (IBAction)shiftSelectionRight:(id)sender
{
	if ([self isEditable])
	{
		NSTextStorage *ts = [self textStorage];
		NSMutableString *scriptString = [[self string] mutableCopy];
		int scriptLength = (int)[scriptString length];
		NSRange selectedRange = [self selectedRange];
		NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
		NSUInteger scanPosition;
		
		// start at the start of the selection and scan backwards over non-newline text until we hit a newline or the start of the file
		scanPosition = selectedRange.location;
		
		while (scanPosition > 0)
		{
			if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition - 1]])
				break;
			
			--scanPosition;
		}
		
		// ok, we're at the start of the line that the selection starts on; start inserting tabs
		[ts beginEditing];
		
		while ((scanPosition == selectedRange.location) || (scanPosition < selectedRange.location + selectedRange.length))
		{
			// insert a tab at the start of this line and adjust our selection
			[ts replaceCharactersInRange:NSMakeRange(scanPosition, 0) withString:@"\t"];
			[scriptString replaceCharactersInRange:NSMakeRange(scanPosition, 0) withString:@"\t"];
			scriptLength++;
			
			if ((scanPosition < selectedRange.location) || (selectedRange.length == 0))
				selectedRange.location++;
			else
				selectedRange.length++;
			
			// now scan forward to the end of this line
			while (scanPosition < scriptLength)
			{
				if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// and then scan forward to the beginning of the next line
			while (scanPosition < scriptLength)
			{
				if (![newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// if we are at the very end of the script string, then we have hit the end and we're done
			if (scanPosition == scriptLength)
				break;
		}
		
		[ts endEditing];
		[self setSelectedRange:selectedRange];
	}
	else
	{
		NSBeep();
	}
}

- (IBAction)commentUncommentSelection:(id)sender
{
	if ([self isEditable])
	{
		NSTextStorage *ts = [self textStorage];
		NSMutableString *scriptString = [[self string] mutableCopy];
		int scriptLength = (int)[scriptString length];
		NSRange selectedRange = [self selectedRange];
		NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
		NSUInteger scanPosition;
		
		// start at the start of the selection and scan backwards over non-newline text until we hit a newline or the start of the file
		scanPosition = selectedRange.location;
		
		while (scanPosition > 0)
		{
			if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition - 1]])
				break;
			
			--scanPosition;
		}
		
		// decide whether we are commenting or uncommenting; we are only uncommenting if every line spanned by the selection starts with "//"
		BOOL uncommenting = YES;
		NSUInteger scanPositionSave = scanPosition;
		
		while ((scanPosition == selectedRange.location) || (scanPosition < selectedRange.location + selectedRange.length))
		{
			// comment/uncomment at the start of this line and adjust our selection
			if ((scanPosition + 1 >= scriptLength) || ([scriptString characterAtIndex:scanPosition] != '/') || ([scriptString characterAtIndex:scanPosition + 1] != '/'))
			{
				uncommenting = NO;
				break;
			}
			
			// now scan forward to the end of this line
			while (scanPosition < scriptLength)
			{
				if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// and then scan forward to the beginning of the next line
			while (scanPosition < scriptLength)
			{
				if (![newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// if we are at the very end of the script string, then we have hit the end and we're done
			if (scanPosition == scriptLength)
				break;
		}
		
		scanPosition = scanPositionSave;
		
		// ok, we're at the start of the line that the selection starts on; start commenting / uncommenting
		[ts beginEditing];
		
		while ((scanPosition == selectedRange.location) || (scanPosition < selectedRange.location + selectedRange.length))
		{
			// if we are at the very end of the script string, then we have hit the end and we're done
			if (uncommenting && (scanPosition == scriptLength))
				break;
			
			// comment/uncomment at the start of this line and adjust our selection
			if (uncommenting)
			{
				[ts replaceCharactersInRange:NSMakeRange(scanPosition, 2) withString:@""];
				[scriptString replaceCharactersInRange:NSMakeRange(scanPosition, 2) withString:@""];
				scriptLength -= 2;
				
				if (scanPosition < selectedRange.location)
				{
					if (scanPosition == selectedRange.location - 1)
					{
						selectedRange.location--;
						if (selectedRange.length > 0)
							selectedRange.length--;
					}
					else
						selectedRange.location -= 2;
				}
				else
				{
					if (selectedRange.length > 2)
						selectedRange.length -= 2;
					else
						selectedRange.length = 0;
				}
			}
			else
			{
				[ts replaceCharactersInRange:NSMakeRange(scanPosition, 0) withString:@"//"];
				[ts setAttributes:[EidosTextView consoleTextAttributesWithColor:[NSColor blackColor]] range:NSMakeRange(scanPosition, 2)];
				[scriptString replaceCharactersInRange:NSMakeRange(scanPosition, 0) withString:@"//"];
				scriptLength += 2;
				
				if ((scanPosition < selectedRange.location) || (selectedRange.length == 0))
					selectedRange.location += 2;
				else
					selectedRange.length += 2;
			}
			
			// now scan forward to the end of this line
			while (scanPosition < scriptLength)
			{
				if ([newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// and then scan forward to the beginning of the next line
			while (scanPosition < scriptLength)
			{
				if (![newlineChars characterIsMember:[scriptString characterAtIndex:scanPosition]])
					break;
				
				++scanPosition;
			}
			
			// if we are at the very end of the script string, then we have hit the end and we're done
			if (!uncommenting && (scanPosition == scriptLength))
				break;
		}
		
		[ts endEditing];
		[self setSelectedRange:selectedRange];
		
		if (syntaxColorState_ == 1)
			[self syntaxColorForEidos];
		else if (syntaxColorState_ == 2)
			[self syntaxColorForOutput];
	}
	else
	{
		NSBeep();
	}
}

// Check whether a token string is a special identifier like "pX", "gX", or "mX"
// FIXME should be in SLiM
- (BOOL)tokenStringIsSpecialIdentifier:(const std::string &)token_string
{
	int len = (int)token_string.length();
	
	if (len >= 2)
	{
		unichar first_ch = token_string[0];
		
		if ((first_ch == 'p') || (first_ch == 'g') || (first_ch == 'm'))
		{
			for (int ch_index = 1; ch_index < len; ++ch_index)
			{
				unichar idx_ch = token_string[ch_index];
				
				if ((idx_ch < '0') || (idx_ch > '9'))
					return NO;
			}
			
			return YES;
		}
	}
	
	return NO;
}

- (void)syntaxColorForEidos
{
	// Construct a Script object from the current script string
	NSString *scriptString = [self string];
	std::string script_string([scriptString UTF8String]);
	EidosScript script(script_string, 0);
	
	// Tokenize
	try
	{
		script.Tokenize(true);	// keep nonsignificant tokens - whitespace and comments
	}
	catch (std::runtime_error err)
	{
		// if we get a raise, we just use as many tokens as we got; clear the error string buffer
		EidosGetUntrimmedRaiseMessage();
		
		//string raise_msg = EidosGetUntrimmedRaiseMessage();
		//NSString *errorString = [NSString stringWithUTF8String:raise_msg.c_str()];
		//NSLog(@"raise during syntax coloring tokenization: %@", errorString);
	}
	
	// Set up our shared colors
	static NSColor *numberLiteralColor = nil;
	static NSColor *stringLiteralColor = nil;
	static NSColor *commentColor = nil;
	static NSColor *identifierColor = nil;
	static NSColor *keywordColor = nil;
	
	if (!numberLiteralColor)
	{
		numberLiteralColor = [[NSColor colorWithCalibratedRed:28/255.0 green:0/255.0 blue:207/255.0 alpha:1.0] retain];
		stringLiteralColor = [[NSColor colorWithCalibratedRed:196/255.0 green:26/255.0 blue:22/255.0 alpha:1.0] retain];
		commentColor = [[NSColor colorWithCalibratedRed:0/255.0 green:116/255.0 blue:0/255.0 alpha:1.0] retain];
		identifierColor = [[NSColor colorWithCalibratedRed:63/255.0 green:110/255.0 blue:116/255.0 alpha:1.0] retain];
		keywordColor = [[NSColor colorWithCalibratedRed:170/255.0 green:13/255.0 blue:145/255.0 alpha:1.0] retain];
	}
	
	// Syntax color!
	NSTextStorage *ts = [self textStorage];
	
	[ts beginEditing];
	
	[ts removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, [ts length])];
	
	for (EidosToken *token : script.Tokens())
	{
		NSRange tokenRange = NSMakeRange(token->token_start_, token->token_end_ - token->token_start_ + 1);
		
		if (token->token_type_ == EidosTokenType::kTokenNumber)
			[ts addAttribute:NSForegroundColorAttributeName value:numberLiteralColor range:tokenRange];
		if (token->token_type_ == EidosTokenType::kTokenString)
			[ts addAttribute:NSForegroundColorAttributeName value:stringLiteralColor range:tokenRange];
		if (token->token_type_ == EidosTokenType::kTokenComment)
			[ts addAttribute:NSForegroundColorAttributeName value:commentColor range:tokenRange];
		if (token->token_type_ > EidosTokenType::kFirstIdentifierLikeToken)
			[ts addAttribute:NSForegroundColorAttributeName value:keywordColor range:tokenRange];
		if (token->token_type_ == EidosTokenType::kTokenIdentifier)
		{
			// most identifiers are left as black; only special ones get colored
			const std::string &token_string = token->token_string_;
			
			if ((token_string.compare("T") == 0) ||
				(token_string.compare("F") == 0) ||
				(token_string.compare("E") == 0) ||
				(token_string.compare("PI") == 0) ||
				(token_string.compare("INF") == 0) ||
				(token_string.compare("NAN") == 0) ||
				(token_string.compare("NULL") == 0) ||
				(token_string.compare("sim") == 0) ||		// FIXME should be in SLiM
				[self tokenStringIsSpecialIdentifier:token_string])
				[ts addAttribute:NSForegroundColorAttributeName value:identifierColor range:tokenRange];
		}
	}
	
	[ts endEditing];
	
	syntaxColorState_ = 1;
}

- (void)syntaxColorForOutput
{
	NSTextStorage *textStorage = [self textStorage];
	NSString *string = [self string];
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	int lineCount = (int)[lines count];
	int stringPosition = 0;
	
	// Set up our shared attributes
	static NSDictionary *poundDirectiveAttrs = nil;
	static NSDictionary *commentAttrs = nil;
	static NSDictionary *subpopAttrs = nil;
	static NSDictionary *genomicElementAttrs = nil;
	static NSDictionary *mutationTypeAttrs = nil;
	
	if (!poundDirectiveAttrs)
	{
		poundDirectiveAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedRed:196/255.0 green:26/255.0 blue:22/255.0 alpha:1.0], NSForegroundColorAttributeName, nil];
		commentAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedRed:0/255.0 green:116/255.0 blue:0/255.0 alpha:1.0], NSForegroundColorAttributeName, nil];
		subpopAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedRed:28/255.0 green:0/255.0 blue:207/255.0 alpha:1.0], NSForegroundColorAttributeName, nil];
		genomicElementAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedRed:63/255.0 green:110/255.0 blue:116/255.0 alpha:1.0], NSForegroundColorAttributeName, nil];
		mutationTypeAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedRed:170/255.0 green:13/255.0 blue:145/255.0 alpha:1.0], NSForegroundColorAttributeName, nil];
	}
	
	// And then tokenize and color
	[textStorage beginEditing];
	[textStorage removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, [textStorage length])];
	
	for (int lineIndex = 0; lineIndex < lineCount; ++lineIndex)
	{
		NSString *line = [lines objectAtIndex:lineIndex];
		NSRange lineRange = NSMakeRange(stringPosition, (int)[line length]);
		int nextStringPosition = (int)(stringPosition + lineRange.length + 1);			// +1 for the newline
		
		if (lineRange.length)
		{
			//NSLog(@"lineIndex %d, lineRange == %@", lineIndex, NSStringFromRange(lineRange));
			
			// find comments and color and remove them
			NSRange commentRange = [line rangeOfString:@"//"];
			
			if ((commentRange.location != NSNotFound) && (commentRange.length == 2))
			{
				int commentLength = (int)(lineRange.length - commentRange.location);
				
				[textStorage addAttributes:commentAttrs range:NSMakeRange(lineRange.location + commentRange.location, commentLength)];
				
				lineRange.length -= commentLength;
				line = [line substringToIndex:commentRange.location];
			}
			
			// if anything is left...
			if (lineRange.length)
			{
				// remove leading whitespace
				do {
					NSRange leadingWhitespaceRange = [line rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSAnchoredSearch];
					
					if (leadingWhitespaceRange.location == NSNotFound || leadingWhitespaceRange.length == 0)
						break;
					
					lineRange.location += leadingWhitespaceRange.length;
					lineRange.length -= leadingWhitespaceRange.length;
					line = [line substringFromIndex:leadingWhitespaceRange.length];
				} while (YES);
				
				// remove trailing whitespace
				do {
					NSRange trailingWhitespaceRange = [line rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet] options:NSAnchoredSearch | NSBackwardsSearch];
					
					if (trailingWhitespaceRange.location == NSNotFound || trailingWhitespaceRange.length == 0)
						break;
					
					lineRange.length -= trailingWhitespaceRange.length;
					line = [line substringToIndex:trailingWhitespaceRange.location];
				} while (YES);
				
				// if anything is left...
				if (lineRange.length)
				{
					// find pound directives and color them
					if ([line characterAtIndex:0] == '#')
						[textStorage addAttributes:poundDirectiveAttrs range:lineRange];
					else
					{
						NSRange scanRange = NSMakeRange(0, lineRange.length);
						
						do {
							NSRange tokenRange = [line rangeOfString:@"\\b[pgm][0-9]+\\b" options:NSRegularExpressionSearch range:scanRange];
							
							if (tokenRange.location == NSNotFound || tokenRange.length == 0)
								break;
							
							NSString *substring = [line substringWithRange:tokenRange];
							NSDictionary *syntaxAttrs = nil;
							
							if ([substring characterAtIndex:0] == 'p')
								syntaxAttrs = subpopAttrs;
							else if ([substring characterAtIndex:0] == 'g')
								syntaxAttrs = genomicElementAttrs;
							else if ([substring characterAtIndex:0] == 'm')
								syntaxAttrs = mutationTypeAttrs;
							
							if (syntaxAttrs)
								[textStorage addAttributes:syntaxAttrs range:NSMakeRange(tokenRange.location + lineRange.location, tokenRange.length)];
							
							scanRange.length = (scanRange.location + scanRange.length) - (tokenRange.location + tokenRange.length);
							scanRange.location = (tokenRange.location + tokenRange.length);
							
							if (scanRange.length < 2)
								break;
						} while (YES);
					}
				}
			}
		}
		
		stringPosition = nextStringPosition;
	}
	
	[textStorage endEditing];
	
	syntaxColorState_ = 2;
}

- (void)clearSyntaxColoring
{
	NSTextStorage *textStorage = [self textStorage];
	
	[textStorage beginEditing];
	[textStorage removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, [textStorage length])];
	[textStorage endEditing];
	
	syntaxColorState_ = 0;
}

- (void)selectErrorRange
{
	if ((gEidosCharacterStartOfParseError >= 0) && (gEidosCharacterEndOfParseError >= gEidosCharacterStartOfParseError))
	{
		NSRange charRange = NSMakeRange(gEidosCharacterStartOfParseError, gEidosCharacterEndOfParseError - gEidosCharacterStartOfParseError + 1);
		
		[self setSelectedRange:charRange];
		[self scrollRangeToVisible:charRange];
	}
}

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
	NSArray *completions = nil;
	
	[self _completionHandlerWithRangeForCompletion:NULL completions:&completions];
	
	return completions;
}

- (NSRange)rangeForUserCompletion
{
	NSRange baseRange = NSMakeRange(NSNotFound, 0);
	
	[self _completionHandlerWithRangeForCompletion:&baseRange completions:NULL];
	
	return baseRange;
}

- (NSMutableArray *)globalCompletionsIncludingStatements:(BOOL)includeStatements
{
	NSMutableArray *globals = [NSMutableArray array];
	EidosSymbolTable *globalSymbolTable = nullptr;
	id delegate = [self delegate];
	
	if ([delegate respondsToSelector:@selector(globalSymbolTableForCompletion)])
		globalSymbolTable = [delegate globalSymbolTableForCompletion];
	
	// First, a sorted list of globals
	if (globalSymbolTable)
	{
		for (std::string &symbol_name : globalSymbolTable->ReadOnlySymbols())
			[globals addObject:[NSString stringWithUTF8String:symbol_name.c_str()]];
		
		for (std::string &symbol_name : globalSymbolTable->ReadWriteSymbols())
			[globals addObject:[NSString stringWithUTF8String:symbol_name.c_str()]];
	}
	
	[globals sortUsingSelector:@selector(compare:)];
	
	// Next, a sorted list of injected functions, with () appended
	if (delegate)
	{
		std::vector<EidosFunctionSignature*> *signatures = nullptr;
		
		if ([delegate respondsToSelector:@selector(injectedFunctionSignatures)])
			signatures = [delegate injectedFunctionSignatures];
		
		if (signatures)
		{
			for (const EidosFunctionSignature *sig : *signatures)
			{
				NSString *functionName = [NSString stringWithUTF8String:sig->function_name_.c_str()];
				
				[globals addObject:[functionName stringByAppendingString:@"()"]];
			}
		}
	}
	
	// Next, a sorted list of functions, with () appended
	for (const EidosFunctionSignature *sig : EidosInterpreter::BuiltInFunctions())
	{
		NSString *functionName = [NSString stringWithUTF8String:sig->function_name_.c_str()];
		
		[globals addObject:[functionName stringByAppendingString:@"()"]];
	}
	
	// Finally, provide language keywords as an option if requested
	if (includeStatements)
	{
		[globals addObject:@"break"];
		[globals addObject:@"do"];
		[globals addObject:@"else"];
		[globals addObject:@"for"];
		[globals addObject:@"if"];
		[globals addObject:@"in"];
		[globals addObject:@"next"];
		[globals addObject:@"return"];
		[globals addObject:@"while"];
		
		// keywords from our Context, if any
		if ([delegate respondsToSelector:@selector(languageKeywordsForCompletion)])
			[globals addObjectsFromArray:[delegate languageKeywordsForCompletion]];
	}
	
	return globals;
}

- (NSMutableArray *)completionsForKeyPathEndingInTokenIndex:(int)lastDotTokenIndex ofTokenStream:(const std::vector<EidosToken *> &)tokens
{
	EidosToken *token = tokens[lastDotTokenIndex];
	EidosTokenType token_type = token->token_type_;
	
	if (token_type != EidosTokenType::kTokenDot)
	{
		NSLog(@"***** completionsForKeyPathEndingInTokenIndex... called for non-kTokenDot token!");
		return nil;
	}
	
	// OK, we've got a key path ending in a dot, and we want to return a list of completions that would work for that key path.
	// We'll trace backward, adding identifiers to a vector to build up the chain of references.  If we hit a bracket, we'll
	// skip back over everything inside it, since subsetting does not change the type; we just need to balance brackets.  If we
	// hit a parenthesis, we give up.  If we hit other things – a semicolon, a comma, a brace – that terminates the key path chain.
	vector<string> identifiers;
	int bracketCount = 0;
	BOOL lastTokenWasDot = YES;
	
	for (int tokenIndex = lastDotTokenIndex - 1; tokenIndex >= 0; --tokenIndex)
	{
		token = tokens[tokenIndex];
		token_type = token->token_type_;
		
		// skip backward over whitespace and comments; they make no difference to us
		if ((token_type == EidosTokenType::kTokenWhitespace) || (token_type == EidosTokenType::kTokenComment))
			continue;
		
		if (bracketCount)
		{
			// If we're inside a bracketed stretch, all we do is balance brackets and run backward.  We don't even clear lastTokenWasDot,
			// because a []. sequence puts us in the same situation as having just seen a dot – we're still waiting for an identifier.
			if (token_type == EidosTokenType::kTokenRBracket)
			{
				bracketCount++;
				continue;
			}
			if (token_type == EidosTokenType::kTokenLBracket)
			{
				bracketCount--;
				continue;
			}
			
			// Check for tokens that simply make no sense, and bail
			if ((token_type == EidosTokenType::kTokenLBrace) || (token_type == EidosTokenType::kTokenRBrace) || (token_type == EidosTokenType::kTokenSemicolon) || (token_type >= EidosTokenType::kFirstIdentifierLikeToken))
				return nil;
			
			continue;
		}
		
		if (!lastTokenWasDot)
		{
			// We just saw an identifier, so the only thing that can continue the key path is a dot
			if (token_type == EidosTokenType::kTokenDot)
			{
				lastTokenWasDot = YES;
				continue;
			}
			
			// the key path has terminated at some non-key-path token, so we're done tracing it
			break;
		}
		
		// OK, the last token was a dot (or a subset preceding a dot).  We're looking for an identifier, but we're willing
		// to get distracted by a subset sequence, since that does not change the type.  Anything else does not make sense.
		// (A method call or function call is possible, actually, but we're not presently equipped to handle them.  The problem
		// is that we don't want to actually call the method/function to get a EidosValue*, because such calls are heavyweight
		// and can have side effects, but without calling the method/function we have no way to get an instance of the type
		// that it would return.  We need the concept of Class objects, but C++ does not do that.  I miss Objective-C.  I'm not
		// sure how to solve this, really; it would require us to have some kind of artificial Class-object-like thing that
		// would know the properties and methods for a given EidosObjectElement class.  Big distortion to the architecture.
		// So for now, we just don't trace back through method/function calls, which sucks.  FIXME)
		if (token_type == EidosTokenType::kTokenIdentifier)
		{
			lastTokenWasDot = NO;
			identifiers.push_back(token->token_string_);
			continue;
		}
		else if (token_type == EidosTokenType::kTokenRBracket)
		{
			bracketCount++;
			continue;
		}
		
		// This makes no sense, so bail
		return nil;
	}
	
	// If we were in the middle of tracing the key path when the loop ended, then something is wrong, bail.
	if (lastTokenWasDot || bracketCount)
		return nil;
	
	// OK, we've got an identifier chain in identifiers, in reverse order.  We want to start at the beginning of the key path,
	// and follow it forward through the properties in the chain to arrive at the final type.
	int key_path_index = (int)identifiers.size() - 1;
	string &identifier_name = identifiers[key_path_index];
	
	EidosSymbolTable *globalSymbolTable = nullptr;
	id delegate = [self delegate];
	
	if ([delegate respondsToSelector:@selector(globalSymbolTableForCompletion)])
		globalSymbolTable = [delegate globalSymbolTableForCompletion];
	
	EidosValue *key_path_value = (globalSymbolTable ? globalSymbolTable->GetValueOrNullForSymbol(identifier_name) : nullptr);
	
	if (!key_path_value)
		return nil;			// unknown symbol at the root, so we have no idea what's going on
	if (key_path_value->Type() != EidosValueType::kValueObject)
	{
		if (key_path_value->IsTemporary()) delete key_path_value;
		return nil;			// the root symbol is not an object, so it should not have a key path off of it; bail
	}
	
	while (--key_path_index >= 0)
	{
		identifier_name = identifiers[key_path_index];
		
		EidosGlobalStringID identifier_id = EidosGlobalStringIDForString(identifier_name);
		
		if (identifier_id == gID_none)
			return nil;			// unrecognized identifier in the key path, so there is probably a typo and we can't complete off of it
		
		EidosValue *property_value = ((EidosValue_Object *)key_path_value)->GetRepresentativeValueOrNullForMemberOfElements(identifier_id);
		
		if (key_path_value->IsTemporary()) delete key_path_value;
		key_path_value = property_value;
		
		if (!key_path_value)
			return nil;			// unknown symbol at the root, so we have no idea what's going on
		if (key_path_value->Type() != EidosValueType::kValueObject)
		{
			if (key_path_value->IsTemporary()) delete key_path_value;
			return nil;			// the root symbol is not an object, so it should not have a key path off of it; bail
		}
	}
	
	// OK, we've now got a EidosValue object that represents the end of the line; the final dot is off of this object.
	// So we want to extract all of its properties and methods, and return them all as candidates.
	NSMutableArray *candidates = [NSMutableArray array];
	EidosValue_Object *terminus = ((EidosValue_Object *)key_path_value);
	
	// First, a sorted list of globals
	for (std::string &symbol_name : terminus->ReadOnlyMembersOfElements())
		[candidates addObject:[NSString stringWithUTF8String:symbol_name.c_str()]];
	
	for (std::string &symbol_name : terminus->ReadWriteMembersOfElements())
		[candidates addObject:[NSString stringWithUTF8String:symbol_name.c_str()]];
	
	[candidates sortUsingSelector:@selector(compare:)];
	
	// Next, a sorted list of functions, with () appended
	for (string &method_name : terminus->MethodsOfElements())
	{
		NSString *methodName = [NSString stringWithUTF8String:method_name.c_str()];
		
		[candidates addObject:[methodName stringByAppendingString:@"()"]];
	}
	
	// Dispose of our terminus
	if (terminus->IsTemporary()) delete terminus;
	
	return candidates;
}

- (NSArray *)completionsForTokenStream:(const std::vector<EidosToken *> &)tokens index:(int)lastTokenIndex canExtend:(BOOL)canExtend
{
	// What completions we offer depends on the token stream
	EidosToken *token = tokens[lastTokenIndex];
	EidosTokenType token_type = token->token_type_;
	
	switch (token_type)
	{
		case EidosTokenType::kTokenNone:
		case EidosTokenType::kTokenEOF:
		case EidosTokenType::kTokenWhitespace:
		case EidosTokenType::kTokenComment:
		case EidosTokenType::kTokenInterpreterBlock:
		case EidosTokenType::kTokenContextFile:
		case EidosTokenType::kTokenContextEidosBlock:
		case EidosTokenType::kFirstIdentifierLikeToken:
			// These should never be hit
			return nil;
			
		case EidosTokenType::kTokenIdentifier:
		case EidosTokenType::kTokenIf:
		case EidosTokenType::kTokenElse:
		case EidosTokenType::kTokenDo:
		case EidosTokenType::kTokenWhile:
		case EidosTokenType::kTokenFor:
		case EidosTokenType::kTokenIn:
		case EidosTokenType::kTokenNext:
		case EidosTokenType::kTokenBreak:
		case EidosTokenType::kTokenReturn:
			if (canExtend)
			{
				NSMutableArray *completions = nil;
				
				// This is the tricky case, because the identifier we're extending could be the end of a key path like foo.bar[5:8].ba...
				// We need to move backwards from the current token until we find or fail to find a dot token; if we see a dot we're in
				// a key path, otherwise we're in the global context and should filter from those candidates
				for (int previousTokenIndex = lastTokenIndex - 1; previousTokenIndex >= 0; --previousTokenIndex)
				{
					EidosToken *previous_token = tokens[previousTokenIndex];
					EidosTokenType previous_token_type = previous_token->token_type_;
					
					// if the token we're on is skippable, continue backwards
					if ((previous_token_type == EidosTokenType::kTokenWhitespace) || (previous_token_type == EidosTokenType::kTokenComment))
						continue;
					
					// if the token we're on is a dot, we are indeed at the end of a key path, and can fetch the completions for it
					if (previous_token_type == EidosTokenType::kTokenDot)
					{
						completions = [self completionsForKeyPathEndingInTokenIndex:previousTokenIndex ofTokenStream:tokens];
						break;
					}
					
					// if we see a semicolon or brace, we are in a completely global context
					if ((previous_token_type == EidosTokenType::kTokenSemicolon) || (previous_token_type == EidosTokenType::kTokenLBrace) || (previous_token_type == EidosTokenType::kTokenRBrace))
					{
						completions = [self globalCompletionsIncludingStatements:YES];
						break;
					}
					
					// if we see any other token, we are not in a key path; let's assume we're following an operator
					completions = [self globalCompletionsIncludingStatements:NO];
					break;
				}
				
				// If we ran out of tokens, we're at the beginning of the file and so in the global context
				if (!completions)
					completions = [self globalCompletionsIncludingStatements:YES];
				
				// Now we have an array of possible completions; we just need to remove those that don't start with our existing prefix
				NSString *baseString = [NSString stringWithUTF8String:token->token_string_.c_str()];
				
				for (int completionIndex = (int)[completions count] - 1; completionIndex >= 0; --completionIndex)
				{
					if (![[completions objectAtIndex:completionIndex] hasPrefix:baseString])
						[completions removeObjectAtIndex:completionIndex];
				}
				
				return completions;
			}
			
			// If the previous token was an identifier and we can't extend it, the next thing probably needs to be an operator or something
			return nil;
			
		case EidosTokenType::kTokenNumber:
		case EidosTokenType::kTokenString:
		case EidosTokenType::kTokenRParen:
		case EidosTokenType::kTokenRBracket:
			// We don't have anything to suggest after such tokens; the next thing will need to be an operator, semicolon, etc.
			return nil;
			
		case EidosTokenType::kTokenDot:
			// This is the other tricky case, because we're being asked to extend a key path like foo.bar[5:8].
			return [self completionsForKeyPathEndingInTokenIndex:lastTokenIndex ofTokenStream:tokens];
			
		case EidosTokenType::kTokenSemicolon:
		case EidosTokenType::kTokenLBrace:
		case EidosTokenType::kTokenRBrace:
			// We are in the global context and anything goes, including a new statement
			return [self globalCompletionsIncludingStatements:YES];
			
		case EidosTokenType::kTokenColon:
		case EidosTokenType::kTokenComma:
		case EidosTokenType::kTokenLParen:
		case EidosTokenType::kTokenLBracket:
		case EidosTokenType::kTokenPlus:
		case EidosTokenType::kTokenMinus:
		case EidosTokenType::kTokenMod:
		case EidosTokenType::kTokenMult:
		case EidosTokenType::kTokenExp:
		case EidosTokenType::kTokenAnd:
		case EidosTokenType::kTokenOr:
		case EidosTokenType::kTokenDiv:
		case EidosTokenType::kTokenAssign:
		case EidosTokenType::kTokenEq:
		case EidosTokenType::kTokenLt:
		case EidosTokenType::kTokenLtEq:
		case EidosTokenType::kTokenGt:
		case EidosTokenType::kTokenGtEq:
		case EidosTokenType::kTokenNot:
		case EidosTokenType::kTokenNotEq:
			// We are following an operator, so globals are OK but new statements are not
			return [self globalCompletionsIncludingStatements:NO];
	}
	
	return nil;
}

- (NSUInteger)rangeOffsetForCompletionRange
{
	// This is for EidosConsoleTextView to be able to remove the prompt string from the string being completed
	return 0;
}

// one funnel for all completion work, since we use the same pattern to answer both questions...
- (void)_completionHandlerWithRangeForCompletion:(NSRange *)baseRange completions:(NSArray **)completions
{
	NSString *scriptString = [self string];
	NSRange selection = [self selectedRange];	// ignore charRange and work from the selection
	NSUInteger rangeOffset = [self rangeOffsetForCompletionRange];
	
	// correct the script string to have only what is entered after the prompt, if we are a EidosConsoleTextView
	if (rangeOffset)
	{
		scriptString = [scriptString substringFromIndex:rangeOffset];
		selection.location -= rangeOffset;
		selection.length -= rangeOffset;
	}
	
	NSUInteger selStart = selection.location;
	
	if (selStart != NSNotFound)
	{
		// Get the substring up to the start of the selection; that is the range relevant for completion
		NSString *scriptSubstring = [scriptString substringToIndex:selStart];
		std::string script_string([scriptSubstring UTF8String]);
		EidosScript script(script_string, 0);
		
		// Tokenize
		try
		{
			script.Tokenize(true);	// keep nonsignificant tokens - whitespace and comments
		}
		catch (std::runtime_error err)
		{
			// if we get a raise, we just use as many tokens as we got; clear the error string buffer
			EidosGetUntrimmedRaiseMessage();
		}
		
		auto tokens = script.Tokens();
		int lastTokenIndex = (int)tokens.size() - 1;
		BOOL endedCleanly = NO, lastTokenInterrupted = NO;
		
		// if we ended with an EOF, that means we did not have a raise and there should be no untokenizable range at the end
		if ((lastTokenIndex >= 0) && (tokens[lastTokenIndex]->token_type_ == EidosTokenType::kTokenEOF))
		{
			--lastTokenIndex;
			endedCleanly = YES;
		}
		
		// if we ended with whitespace or a comment, the previous token cannot be extended
		while (lastTokenIndex >= 0) {
			EidosToken *token = tokens[lastTokenIndex];
			
			if ((token->token_type_ != EidosTokenType::kTokenWhitespace) && (token->token_type_ != EidosTokenType::kTokenComment))
				break;
			
			--lastTokenIndex;
			lastTokenInterrupted = YES;
		}
		
		// now diagnose what range we want to use as a basis for completion
		if (!endedCleanly)
		{
			// the selection is at the end of an untokenizable range; we might be in the middle of a string or a comment,
			// or there might be a tokenization error upstream of us.  let's not try to guess what the situation is.
			if (baseRange) *baseRange = NSMakeRange(NSNotFound, 0);
			if (completions) *completions = nil;
			return;
		}
		else if (lastTokenInterrupted)
		{
			if (lastTokenIndex < 0)
			{
				// We're at the end of nothing but initial whitespace and comments; offer insertion-point completions
				if (baseRange) *baseRange = NSMakeRange(selection.location + rangeOffset, 0);
				if (completions) *completions = [self globalCompletionsIncludingStatements:YES];
				return;
			}
			
			EidosToken *token = tokens[lastTokenIndex];
			EidosTokenType token_type = token->token_type_;
			
			// the last token cannot be extended, so if the last token is something an identifier can follow, like an
			// operator, then we can offer completions at the insertion point based on that, otherwise punt.
			if ((token_type == EidosTokenType::kTokenNumber) || (token_type == EidosTokenType::kTokenString) || (token_type == EidosTokenType::kTokenRParen) || (token_type == EidosTokenType::kTokenRBracket) || (token_type == EidosTokenType::kTokenIdentifier) || (token_type == EidosTokenType::kTokenIf) || (token_type == EidosTokenType::kTokenWhile) || (token_type == EidosTokenType::kTokenFor) || (token_type == EidosTokenType::kTokenNext) || (token_type == EidosTokenType::kTokenBreak) || (token_type == EidosTokenType::kTokenReturn))
			{
				if (baseRange) *baseRange = NSMakeRange(NSNotFound, 0);
				if (completions) *completions = nil;
				return;
			}
			
			if (baseRange) *baseRange = NSMakeRange(selection.location + rangeOffset, 0);
			if (completions) *completions = [self completionsForTokenStream:tokens index:lastTokenIndex canExtend:NO];
			return;
		}
		else
		{
			if (lastTokenIndex < 0)
			{
				// We're at the very beginning of the script; offer insertion-point completions
				if (baseRange) *baseRange = NSMakeRange(selection.location + rangeOffset, 0);
				if (completions) *completions = [self globalCompletionsIncludingStatements:YES];
				return;
			}
			
			// the last token was not interrupted, so we can offer completions of it if we want to.
			EidosToken *token = tokens[lastTokenIndex];
			NSRange tokenRange = NSMakeRange(token->token_start_, token->token_end_ - token->token_start_ + 1);
			
			if (token->token_type_ >= EidosTokenType::kTokenIdentifier)
			{
				if (baseRange) *baseRange = NSMakeRange(tokenRange.location + rangeOffset, tokenRange.length);
				if (completions) *completions = [self completionsForTokenStream:tokens index:lastTokenIndex canExtend:YES];
				return;
			}
			
			if ((token->token_type_ == EidosTokenType::kTokenNumber) || (token->token_type_ == EidosTokenType::kTokenString) || (token->token_type_ == EidosTokenType::kTokenRParen) || (token->token_type_ == EidosTokenType::kTokenRBracket))
			{
				if (baseRange) *baseRange = NSMakeRange(NSNotFound, 0);
				if (completions) *completions = nil;
				return;
			}
			
			if (baseRange) *baseRange = NSMakeRange(selection.location + rangeOffset, 0);
			if (completions) *completions = [self completionsForTokenStream:tokens index:lastTokenIndex canExtend:NO];
			return;
		}
	}
}

@end




























































