// Copyright © 2010 John Judnich. All rights reserved.

#import "XScript.h"
#import <stdio.h>


typedef enum
{
	TOKEN_Text,
	TOKEN_NewLine,
	TOKEN_OpenBrace,
	TOKEN_CloseBrace,
	TOKEN_EOF,
} Token;

@interface XScriptParser : NSObject
{
	char *parseBuff, *parseBuffEnd, *buffPtr;
	size_t parseBuffLen;
	
	Token tok, lastTok;
	NSMutableString *tokVal, *lastTokVal;
	char *lastTokPos;
}

-(id)init;
-(void)dealloc;

-(BOOL)parseDataIntoNode:(XScriptNode*)node fromData:(char*)data dataLength:(int)dataLen;

-(BOOL)_parseNodes:(XScriptNode*)parent;
-(void)_nextToken;
-(void)_prevToken;

@end


@implementation XScriptNode

@synthesize values, subnodes, parentNode;

-(id)initWithFile:(NSString*)filename
{
	if ((self = [super init])) {
		// init as root node
		name = @"[ROOT]";
		[name retain];
		parentNode = nil;
		values = [[NSMutableArray alloc] init];
		subnodes = [[NSMutableArray alloc] init];

		// open file and read the contents into memory
		NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
		NSString *directory = [filename stringByDeletingLastPathComponent];
		NSString *fileN = [filename lastPathComponent];
		NSString *sourcePath = [[NSBundle mainBundle] pathForResource:fileN ofType:nil inDirectory:directory];
		FILE *file = fopen([sourcePath UTF8String], "rb");
		if (file == NULL) {
			[values release];
			[subnodes release];
			[name release];
			[autoreleasePool release];
			NSLog(@"Error reading script file \"%@\": File not found", filename);
			return nil;
		}
		fseek(file, 0, SEEK_END);
		size_t fileSize = ftell(file);
		rewind(file);
		char *fileContents = (char*)malloc(fileSize);
		if (fileContents == NULL) {
			fclose(file);
			[autoreleasePool release];
			NSLog(@"MEMORY ERROR: Out of memory");
			return nil;
		}
		if (fread(fileContents, fileSize, 1, file) != 1) {
			free(fileContents);
			[autoreleasePool release];
			NSLog(@"READ ERROR: Could not read file");
			return nil;
		}
		fclose(file);
		
		// parse the script
		XScriptParser *parser = [[XScriptParser alloc] init];
		if (![parser parseDataIntoNode:self fromData:fileContents dataLength:fileSize]) {
			[parser release];
			[name release];
			[values release];
			[subnodes release];
			free(fileContents);
			[autoreleasePool release];
			NSLog(@"Aborted loading script file due to errors.");
			return nil;
		}
		[parser release];
		
		// release file
		free(fileContents);
		[autoreleasePool release];
	}
	return self;
}

-(id)initWithName:(NSString*)nodeName
{
	if ((self = [super init])) {
		name = nodeName;
		[name retain];
		values = [[NSMutableArray alloc] init];
		subnodes = [[NSMutableArray alloc] init];
	}
	return self;
}

-(void)dealloc
{
	[values removeAllObjects];
	[values release];
	[subnodes removeAllObjects];
	[subnodes release];
	[name release];
	[super dealloc];
}

-(void)setName:(NSString*)newName
{
	[name release];
	name = newName;
	[name retain];
}

-(NSString*)name
{
	return name;
}

-(void)addSubnode:(XScriptNode*)subnode
{
	if (subnode->parentNode == nil) {
		subnode->parentNode = self;
		[subnodes addObject:subnode];
	} else {
		NSLog(@"Error adding XScriptNode subnode: Subnode is already assigned to another parent node.");
	}
}

-(void)removeSubnode:(XScriptNode*)subnode
{
	subnode->parentNode = nil;
	[subnodes removeObject:subnode];
}

-(int)subnodeCount
{
	return subnodes.count;
}

-(XScriptNode*)getSubnodeByIndex:(int)index
{
	if (index < subnodes.count)
		return [subnodes objectAtIndex:index];
	else return nil;
}

-(XScriptNode*)getSubnodeByName:(NSString*)searchName
{
	for (XScriptNode *node in subnodes) {
		if ([node.name isEqualToString:searchName])
			return node;
	}
	return nil;
}

-(NSArray*)subnodesWithName:(NSString*)searchName
{
	NSMutableArray *results = [[NSMutableArray alloc] init];
	for (XScriptNode *node in subnodes) {
		if ([node.name isEqualToString:searchName])
			[results addObject:node];
	}
	NSArray *retVal = nil;
	if (results.count > 0) {
		retVal = [[NSArray alloc] initWithArray:results];
		[retVal autorelease];
	}
	[results release];
	return retVal;
}

-(int)valueCount
{
	return values.count;
}

-(NSString*)getValue:(int)index
{
	if (index < values.count) {
		NSString *val = [values objectAtIndex:index];
		return val;
	}
	else return nil;
}

-(float)getValueF:(int)index
{
	if (index < values.count) {
		NSString *val = [values objectAtIndex:index];
		return val.floatValue;
	}
	else return 0;
}

-(double)getValueD:(int)index
{
	if (index < values.count) {
		NSString *val = [values objectAtIndex:index];
		return val.doubleValue;
	}
	else return 0;
}

-(int)getValueI:(int)index
{
	if (index < values.count) {
		NSString *val = [values objectAtIndex:index];
		return val.intValue;
	}
	else return 0;
}

@end


@implementation XScriptParser

-(id)init
{
	if ((self = [super init])) {
		tokVal = [[NSMutableString alloc] init];
		lastTokVal = [[NSMutableString alloc] init];
	}
	return self;
}

-(void)dealloc
{
	[tokVal release];
	[lastTokVal release];
	[super dealloc];
}

-(BOOL)parseDataIntoNode:(XScriptNode*)node fromData:(char*)data dataLength:(int)dataLen
{
	parseBuff = data;
	buffPtr = parseBuff;
	parseBuffEnd = parseBuff + dataLen;

	//get first token
	[self _nextToken];
	if (tok == TOKEN_EOF)
		return NO;
	
	//Parse the script
	if (![self _parseNodes:node])
		return NO;
	
	if (tok == TOKEN_CloseBrace) {
		NSLog(@"XScript Parse Error: Closing brace out of place");
		return NO;
	}
	
	return YES;
}

-(void)_nextToken
{
	lastTok = tok;
	lastTokPos = buffPtr;
	[lastTokVal setString:tokVal];
	
	// EOF token
	if (buffPtr >= parseBuffEnd){
		tok = TOKEN_EOF;
		return;
	}
	
	// (get next character)
	int ch = *buffPtr++;
	while (ch == ' ' || ch == 9){	//Skip leading spaces / tabs
		ch = *buffPtr++;
	}
	
	// newline token
	if (ch == '\r' || ch == '\n'){
		do {
			ch = *buffPtr++;
		} while ((ch == '\r' || ch == '\n') && buffPtr < parseBuffEnd);
		buffPtr--;
		
		tok = TOKEN_NewLine;
		return;
	}
	
	// open brace token
	else if (ch == '{'){
		tok = TOKEN_OpenBrace;
		return;
	}
	
	// close brace token
	else if (ch == '}'){
		tok = TOKEN_CloseBrace;
		return;
	}
	
	// text token
	if (ch < 32 || ch > 122) {	//verify valid char
		NSLog(@"Parse Error: Invalid character");
		[NSException raise:@"Parse Error" format:@"Invalid character"];
		tok = TOKEN_NewLine;
		return;
	}

	char tokValBuff[256];
	int tokValBuffLen = 0;
	tok = TOKEN_Text;
	BOOL inQuotes = NO;
	do {
		do {
			// skip comments
			if (ch == '/'){
				int ch2 = *buffPtr;
				
				// C++ style comment (//)
				if (ch2 == '/'){
					buffPtr++;
					do {
						ch = *buffPtr++;
					} while (ch != '\r' && ch != '\n' && buffPtr < parseBuffEnd);
					
					tok = TOKEN_NewLine;
					return;
				}
			}
			
			// track quotes
			if (ch == '\"') {
				inQuotes = !inQuotes;
			}
			else {
				// add valid char to tokVal
				tokValBuff[tokValBuffLen++] = ch;
			}
			
			// next char
			ch = *buffPtr++;
		} while (ch > 32 && ch <= 122 && buffPtr < parseBuffEnd);
		if (ch != 32) inQuotes = NO; //don't follow quotes beyond line/file end
	} while (inQuotes);
	buffPtr--;
	
	// save token text
	tokValBuff[tokValBuffLen++] = '\0';
	[tokVal setString:[NSString stringWithUTF8String:tokValBuff]];
	
	return;
}

-(void)_prevToken
{
	tok = lastTok;
	buffPtr = lastTokPos;
	[tokVal setString:lastTokVal];
}	

-(BOOL)_parseNodes:(XScriptNode*)parent
{
	while (1) {
		switch (tok) {
			// node
			case TOKEN_Text: {
				// add the new node
				XScriptNode *newNode = [[XScriptNode alloc] initWithName:[NSString stringWithString:tokVal]];
				[parent addSubnode:newNode];
				[newNode release];
				
				// get values
				[self _nextToken];
				while (tok == TOKEN_Text) {
					[newNode.values addObject:[NSString stringWithString:tokVal]];
					[self _nextToken];
				}
				
				// skip any blank spaces
				while (tok == TOKEN_NewLine)
					[self _nextToken];
				
				// add any sub-nodes
				if (tok == TOKEN_OpenBrace){
					// parse nodes
					[self _nextToken];
					[self _parseNodes:newNode];
					
					// skip blank spaces
					while (tok == TOKEN_NewLine)
						[self _nextToken];
					
					// check for matching closing brace
					if (tok != TOKEN_CloseBrace) {
						NSLog(@"Parse Error: Expecting closing brace");
						return NO;
					}
				} else {
					// if it's not a opening brace, back up so the system will parse it properly
					[self _prevToken];
				}
			break; }
				
			// out of place brace
			case TOKEN_OpenBrace:
				NSLog(@"Parse Error: Opening brace out of plane");
				return NO;
				break;
				
			// return if end of nodes have been reached
			case TOKEN_CloseBrace:
				return YES;
				
			// return if reached end of file
			case TOKEN_EOF:
				return YES;
			
			// ignore newlines
			case TOKEN_NewLine:
				break;
		}
		
		//Next token
		[self _nextToken];
	};
}

@end
