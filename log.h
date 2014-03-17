//
//  Created by K3A on 5/20/12.
//  Copyright (c) 2012 K3A. All rights reserved.
//

#pragma once

void LogInfo(const char* function, const char* desc, ...);
void FlushLog();
#define Info(desc, ...) LogInfo("", desc, ##__VA_ARGS__)
