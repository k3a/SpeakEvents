
//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import "KStringAdditions.h"

@implementation NSString (SpeakEventsAdditions)

-(NSString*)stringWithFirstUppercase
{
    if ([self length] == 0) 
        return [[self copy] autorelease];
    
    NSString* firstCh = [[self substringToIndex:1] uppercaseString];
    return [firstCh stringByAppendingString:[self substringFromIndex:1]];
}

-(NSString*)urlEncodedString
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                           (CFStringRef)self, NULL, CFSTR(":/?#[]@!$&'()*+,;="), kCFStringEncodingUTF8);
    return [result autorelease];
}

- (BOOL)doesContainSubstring:(NSString *)substring
{
    //If self or substring have 0 length they cannot match
    //This can have odd results with NSRange
    if([self length] == 0 || [substring length] == 0)
        return NO;
    
    NSRange textRange;
    
    textRange = [[self lowercaseString] rangeOfString:[substring lowercaseString]];
    
    if(textRange.location != NSNotFound)
    {
        return YES;
    }else{
        return NO;
    }
    
}

@end
