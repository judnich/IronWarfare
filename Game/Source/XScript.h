// Copyright © 2010 John Judnich. All rights reserved.


@interface XScriptNode : NSObject {
	NSString *name;
	NSMutableArray *values;
	NSMutableArray *subnodes;
	XScriptNode *parentNode;
}

@property(readonly) NSMutableArray *values;
@property(readonly) NSMutableArray *subnodes;
@property(readonly) XScriptNode *parentNode;
@property(retain) NSString *name;
@property(readonly) int valueCount;
@property(readonly) int subnodeCount;

-(id)initWithFile:(NSString*)filename;
-(id)initWithName:(NSString*)nodeName;
-(void)dealloc;

-(void)addSubnode:(XScriptNode*)subnode;
-(void)removeSubnode:(XScriptNode*)subnode;

-(XScriptNode*)getSubnodeByIndex:(int)index;
-(XScriptNode*)getSubnodeByName:(NSString*)searchName;
-(NSArray*)subnodesWithName:(NSString*)searchName;

-(NSString*)getValue:(int)index;
-(float)getValueF:(int)index;
-(double)getValueD:(int)index;
-(int)getValueI:(int)index;

@end
