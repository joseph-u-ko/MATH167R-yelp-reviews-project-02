
1. Problems Encountered

The primary obstacle encountered when working with the Yelp Academic Dataset—specifically yelp_academic_dataset_review.json—was severe memory saturation (RAM depletion). Standard JSON parsing functions in R, such as jsonlite::fromJSON(), attempt to load an entire file structure into memory at once. Because the reviews file contains millions of rows of dense text data, this immediately exceeded available RAM, causing R sessions to freeze and crash. Additionally, the dataset contained multiple metadata columns that were irrelevant to the immediate analysis goal, which drastically increased import times and disk space usage.
A different challenge arose with yelp_academic_dataset_business.json. While significantly smaller than the review dataset, it contained heavily nested structural elements (such as operational hours and business attributes). Importing it without flattening would preserve complex data structures that do not map cleanly to standard data frames, complicating downstream data manipulation and flat-file exports.

2. Strategy and Implementation

To overcome these computing and structural constraints, a multi-tiered data pipeline was engineered to process, filter, flatten, and compress both datasets efficiently:

Phase A: Chunked Streaming and Filtering (Reviews Dataset)
- Chunked Processing (Streaming): Instead of parsing the massive review file simultaneously, the jsonlite::stream_in() function was paired with a custom callback handler. By initializing a pagesize = 50000, the dataset was divided and read in manageable blocks.
- Column Selection On-The-Fly: Within the callback loop, memory footprint reduction was prioritized by immediately subsetting each chunk to retain only five essential columns: review_id, business_id, stars, date, and text. Unused attributes were discarded dynamically prior to serialization, ensuring R only held a tiny fraction of the data in RAM at any given moment.
- Intermediary Disk Storage: To safely persist the data without risking a memory crash, the processed chunks were appended to a flat file on disk (yelp_reviews_subset.csv). Quotation marks within the review strings were strictly managed using the qmethod = "double" parameter to prevent formatting failures caused by unescaped user text.

Phase B: Flattening and Direct Conversion (Business Dataset)
- Nested Structure Flattening: Because the business dataset fits within standard RAM limits, it was processed as a single stream but passed through a flattening parameters framework (flatten = TRUE). This automatically unpacked nested lists (e.g., parking options, price ranges, and daily hours) into discrete, independent tabular columns.
- Multi-Format Export: The flattened business data frame was written directly to disk as a structured flat file (yelp_businesses.csv) using the highly optimized vroom::vroom_write() function to ensure clean formatting across complex column attributes.

Phase C: Binary Serialization and RDS Compression
- Binary Compressing (.rds): To optimize long-term storage and eliminate future text-parsing overhead, both the filtered review dataset and the flattened business dataset were converted into R's native binary format using saveRDS().
- Workspace Optimization: The resulting .rds files drastically reduced file sizes on disk through built-in compression. Furthermore, this approach eliminated the need to re-parse raw JSON or CSV files in future sessions. The clean datasets can now be loaded into R almost instantaneously using readRDS(), providing a fast, stable, and highly optimized environment for downstream analysis.