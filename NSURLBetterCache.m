//
// NSURLBetterCache.h
// NSURLBetterCache (https://github.com/xEsk/NSURLBetterCache)
//
// Created by Xesc on 28/01/19.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import "NSURLBetterCache.h"

#import <sqlite3.h>

@interface NSURLBetterCache ()

@property (readonly) NSString *cacheDirectory;

@end

@implementation NSURLBetterCache

- (instancetype)init
{
    if (self = [super init])
    {
        NSString *CFBundleIdentifier = [NSBundle mainBundle].infoDictionary[@"CFBundleIdentifier"];
        // get the cache directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        _cacheDirectory = [[paths lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"Caches/%@", CFBundleIdentifier]];
    }
    return self;
}

- (NSArray *)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable
{
    sqlite3 *sqlite3Database;
    // init arrays
    NSMutableArray *arrResults = [NSMutableArray array];
    // Open the database.
    if (sqlite3_open([[self.cacheDirectory stringByAppendingPathComponent:@"Cache.db"] UTF8String], &sqlite3Database) == SQLITE_OK)
    {
        // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
        sqlite3_stmt *compiledStatement;
        // Load all data from database to memory.
        if (sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL) == SQLITE_OK)
        {
            // Check if the query is non-executable.
            if ( ! queryExecutable)
            {
                // Loop through the results and add them to the results array row by row.
                while (sqlite3_step(compiledStatement) == SQLITE_ROW)
                {
                    // Initialize the mutable array that will contain the data of a fetched row.
                    NSMutableArray *arrDataRow = [NSMutableArray array];
                    NSMutableArray *arrColumnNames = [NSMutableArray array];
                    // Get the total number of columns.
                    int totalColumns = sqlite3_column_count(compiledStatement);
                    // Go through all columns and fetch each column data.
                    for (int i = 0; i < totalColumns; i++)
                    {
                        // Convert the column data to text (characters).
                        char *dbDataAsChars = (char *)sqlite3_column_text(compiledStatement, i);
                        // If there are contents in the currenct column (field) then add them to the current row array.
                        if (dbDataAsChars != NULL)
                        {
                            id value = [NSString stringWithUTF8String:dbDataAsChars];
                            if ( ! value) value = [NSData dataWithBytes:dbDataAsChars length:StrLength(dbDataAsChars)];
                            // Add this value into data row
                            [arrDataRow addObject:value];
                            // Keep the current column name.
                            if (arrColumnNames.count != totalColumns)
                            {
                                dbDataAsChars = (char *)sqlite3_column_name(compiledStatement, i);
                                [arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                            }
                        }
                    }
                    // Store each fetched data row in the results array, but first check if there is actually data.
                    if (arrDataRow.count > 0)
                    {
                        [arrResults addObject:[NSDictionary dictionaryWithObjects:arrDataRow forKeys:arrColumnNames]];
                    }
                }
            }
            else if (sqlite3_step(compiledStatement) != SQLITE_DONE)
            {
                NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
            }
        }
        else // In the database cannot be opened then show the error message on the debugger.
        {
            NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
        }
        // Release the compiled statement from memory.
        sqlite3_finalize(compiledStatement);
    }
    // Close the database.
    sqlite3_close(sqlite3Database);
    // get back the results
    return arrResults;
}

- (void)removeCachedResponsesSinceDate:(NSDate *)date
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    // filter DB with older entries
    NSString *query = [NSString stringWithFormat:@"SELECT entry_ID FROM cfurl_cache_response WHERE time_stamp < '%@'", [formatter stringFromDate:date]];
    NSArray *results = [self runQuery:[query UTF8String] isQueryExecutable:NO];
    // init the file manager
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fsCachedDataDirectory = [self.cacheDirectory stringByAppendingPathComponent:@"fsCachedData"];
    NSMutableArray *entry_IDs = [NSMutableArray array];
    // remove old cached elements on disk
    [results enumerateObjectsUsingBlock:^(NSDictionary *row, NSUInteger idx, BOOL *stop)
    {
        NSString *entry_ID = row[@"entry_ID"];
        // add this id into the IDs to delete
        [entry_IDs addObject:[NSString stringWithFormat:@"entry_ID = '%@'", entry_ID]];
        // remove the blob (if exists)
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM cfurl_cache_receiver_data WHERE entry_ID = %@", entry_ID];
        NSDictionary *dataInfo = [[self runQuery:[query UTF8String] isQueryExecutable:NO] firstObject];
        // should delete the file in disk?
        if ([dataInfo[@"isDataOnFS"] boolValue])
        {
            NSError *error = nil;
            // remove the data file from disk
            if ( ! [fileManager removeItemAtPath:[fsCachedDataDirectory stringByAppendingPathComponent:dataInfo[@"receiver_data"]] error:&error])
            {
                NSLog(@"%@", error.localizedDescription);
            }
        }
    }];
    // delete all cache entries
    if (entry_IDs.count > 0)
    {
        NSString *IDs_query = [entry_IDs componentsJoinedByString:@" OR "];
        [self runQuery:[[NSString stringWithFormat:@"DELETE FROM cfurl_cache_blob_data WHERE %@", IDs_query] UTF8String] isQueryExecutable:YES];
        [self runQuery:[[NSString stringWithFormat:@"DELETE FROM cfurl_cache_receiver_data WHERE %@", IDs_query] UTF8String] isQueryExecutable:YES];
        [self runQuery:[[NSString stringWithFormat:@"DELETE FROM cfurl_cache_response WHERE %@", IDs_query] UTF8String] isQueryExecutable:YES];
        // log info
        NSLog(@"Invalidated %ld elements from cache.", entry_IDs.count);
    }
}

@end
