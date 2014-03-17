//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//


#include "log.h"

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <UIKit/UIKit.h>

void LogInfo(const char* function, const char* desc, ...)
{
	static char buffer[1024];
	
	va_list argList;
	va_start(argList, desc);
	vsprintf(buffer, desc, argList);
	va_end(argList);
	
	// get time
	time_t tim;
	time(&tim);
	tm *timm = localtime(&tim);
	int tda = timm->tm_mday;
	int tmo = timm->tm_mon+1;
	int tho = timm->tm_hour;
	int tmi = timm->tm_min;
	
	char buffer2[2048];
	sprintf(buffer2, "ObjcDump[%d.%d@%d:%d]: %d: %s\r\n", tda, tmo, tho, tmi, getpid(), buffer);
	
	//print
	//printf("%s", buffer2);
    NSLog(@"%s", buffer2);
}

void FlushLog()
{
    static volatile int i=0;
    i++;
    //fflush(fp);
}

