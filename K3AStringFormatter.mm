//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "K3AStringFormatter.h"

@implementation K3AStringFormatter
@synthesize format;

+(K3AStringFormatter*)formatterWithFormat:(NSString*)f
{
    return [[K3AStringFormatter alloc] initWithFormatString:f];
}

-(K3AStringFormatter*)initWithFormatString:(NSString*)f
{
    if ( (self = [super init]) )
    {
        _args = [NSMutableArray new];
        self.format = f;
    }
    return self;
}

-(void)dealloc
{
    [_args release];
    [format release];
    [super dealloc];
}

-(K3AStringFormatter*)addString:(NSString*)arg
{
    [_args addObject:arg];
    return self;
}
-(K3AStringFormatter*)addFloat:(float)arg
{
    [_args addObject:[NSString stringWithFormat:@"%.2f", arg]];
    return self;
}
-(K3AStringFormatter*)addInt:(int)arg
{
    [_args addObject:[NSString stringWithFormat:@"%d", arg]];
    return self;
}

-(NSString*)generateString
{
    unsigned numArgs = [_args count];
    NSMutableString* outStr = [NSMutableString stringWithString:format];
    
    for (unsigned i=0; i<numArgs; i++)
    {
        NSString* str = [NSString stringWithFormat:@"%%%d", i+1];
        [outStr replaceOccurrencesOfString:str withString:[_args objectAtIndex:i] 
                                   options:NSLiteralSearch 
                                     range:NSMakeRange(0, [outStr length])];
    }

	//replance pauses
	[outStr replaceOccurrencesOfString:@"/100/" withString:@"\x1b\\pause=100\\" options:NSLiteralSearch range:NSMakeRange(0, [outStr length])];
	[outStr replaceOccurrencesOfString:@"/500/" withString:@"\x1b\\pause=500\\" options:NSLiteralSearch range:NSMakeRange(0, [outStr length])];
     
    return outStr;
}

@end
