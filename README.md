Intro
=======

This is a direct replacment for **NSURLCache**.

Some times (or almost ervery time) you try to invalidate cached elements older than a date it doesn't work like expected (sigh), so is then when **NSURLBetterCache** enters in action with an implemntation made from the ground to fix it.

Apple's NSURLCache in action:

```objc
NSInteger days = 7;
NSDate *date = [[NSDate date] dateByAddingTimeInterval:-days*24*60*60];
    
// before
NSLog(@"a) DISK USAGE: %ld", [NSURLCache sharedURLCache].currentDiskUsage);
NSLog(@"a) MEMO USAGE: %ld", [NSURLCache sharedURLCache].currentMemoryUsage);
	
// invalidate cached elements older than a week
[[NSURLCache sharedURLCache] removeCachedResponsesSinceDate:date];

// after
NSLog(@"b) DISK USAGE: %ld", [NSURLCache sharedURLCache].currentDiskUsage);
NSLog(@"b) MEMO USAGE: %ld", [NSURLCache sharedURLCache].currentMemoryUsage);
```
**Output:**

```
2019-01-28 17:24:54.377915+0100 Test[27546:1092366] a) DISK USAGE: 589098
2019-01-28 17:24:54.378113+0100 Test[27546:1092366] a) MEMO USAGE: 0
 
2019-01-28 17:24:54.399627+0100 Test[27546:1092366] b) DISK USAGE: 589098
2019-01-28 17:24:54.399917+0100 Test[27546:1092366] b) MEMO USAGE: 0
```

As you can see, nothing happened (before 589.098 bytes, after 589.098 bytes)

Now, **NSURLBetterCache** in action:

We only need to add two lines of code:

```objc
#import "NSURLBetterCache.h"

(...)

// replace the default URLCache whith this NSURLBetterCache
[NSURLCache setSharedURLCache:[NSURLBetterCache new]];

```

Then we execute the **SAME** code as showed before in **Apple's NSURLCache example**, and check out the result:

**Output:**

```
2019-01-28 17:31:50.749513+0100 Test[27649:1101516] a) DISK USAGE: 589098
2019-01-28 17:31:50.749762+0100 Test[27649:1101516] a) MEMO USAGE: 0

2019-01-28 17:31:50.799388+0100 Test[27649:1101516] Invalidated 20 elements from cache.

2019-01-28 17:31:50.800500+0100 Test[27649:1101516] b) DISK USAGE: 353627
2019-01-28 17:31:50.800708+0100 Test[27649:1101516] b) MEMO USAGE: 0
```

Now, the 20 elements has been removed from your cache (before 589.098 bytes, after 353.627 bytes).

Enjoy it!