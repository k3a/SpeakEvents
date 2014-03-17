//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface K3AStringFormatter : NSObject {
    NSMutableArray* _args; 
}

@property(nonatomic, copy) NSString* format;

+(K3AStringFormatter*)formatterWithFormat:(NSString*)f;
-(K3AStringFormatter*)initWithFormatString:(NSString*)f;

-(K3AStringFormatter*)addString:(NSString*)arg;
-(K3AStringFormatter*)addFloat:(float)arg;
-(K3AStringFormatter*)addInt:(int)arg;

-(NSString*)generateString;

@end
