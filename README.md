# MATH167R-yelp-reviews-project-02

## One-Sentence Research Question
> __Where can someone find the best restaurants in a selected category in New Orleans, and which geographic area is best for finding them?__
>> Define “best” using evidence such as ratings, review volume, reviewer-adjusted scores, and the reliability of the comparison. Your final question should name your selected restaurant category or theme.

## Short Executive Summary


## Data Sources and Cleaning Decisions
> Add a section to your report explaining how you handled the large dataset. Describe problems you encountered, such as low memory, limited disk space, a slow computer, a failed download, or a long import time, and explain how you overcame them. You should research solutions appropriate for your computer, such as using a documented sample during development, processing the review file in chunks, keeping only necessary columns, saving filtered data as compressed .rds files, and deleting or managing temporary files. A sample is acceptable for testing code, but it is not acceptable as the final result unless I have approved that choice. Your final results must use the complete set of New Orleans restaurant businesses and all available Yelp reviews for those businesses.
Here is the complete, submission-ready explanation of how you handled the dataset, structured exactly around your workflow and the criteria in the prompt. You can copy and paste this directly into your report or assignment.

1. Problems Encountered

The primary obstacle encountered when working with the yelp_academic_dataset_review.json file was severe memory saturation (RAM depletion). Standard JSON parsing functions in R, such as jsonlite::fromJSON() or raw stream_in(), attempt to load the entire file structure into memory at once. Because the Yelp reviews file contains millions of rows of text data and complex line-by-line nested metadata, this immediately exceeded available RAM, causing R sessions to slow down drastically, freeze, and ultimately crash.
Additionally, the dataset contained multiple metadata columns (such as voting scores and user metrics) that were irrelevant to the immediate analysis goal, further exacerbating the long import times and storage footprint.

2. Strategy and Implementation

To overcome these computing constraints, the development workflow was re-engineered to process the data efficiently without overloading system resources:
* Chunked Processing (Streaming): Instead of parsing the entire file simultaneously, the jsonlite::stream_in() function was paired with a custom callback handler. By setting a pagesize = 50000, the dataset was divided and read in manageable blocks of 50,000 rows at a time.
* Column Selection On-The-Fly: Within the callback loop, memory footprint reduction was prioritized by immediately subsetting each chunk to retain only the essential columns: review_id, business_id, stars, date, and text. Unused attributes were discarded dynamically prior to serialization, ensuring R only held a tiny fraction of the data in RAM at any given moment.
* Text Escaping & Disk Persistence: Each subsetted data frame chunk was sequentially appended to a flat file on disk (yelp_reviews_subset.csv). To prevent formatting failures caused by messy user text, quotation marks within the review strings were strictly managed using the qmethod = "double" parameter to maintain data integrity.
* Lazy Loading for Analysis: Once the dense, filtered CSV was generated, read.csv() was avoided. Instead, the memory-mapped vroom package was utilized to index the fields instantly, allowing for seamless downstream manipulation without hitting memory limits.
 
DELETE THIS BEFORE SUBMITTING PROJECT (url for Google Gemini's chat if needed): https://www.google.com/search?q=how+to+import+the+yelp_academic_dataset_review.json+into+R&sca_esv=90d2fa9b8953502e&rlz=1C1UEAD_enUS1092US1092&biw=2560&bih=1260&sxsrf=AKL5yDj9C_TFOjbXukVCYHblP1nFMOekKg%3A1793514138102&ei=mtrmavrmBZqikPIPrKo5&uact=5&oq=how+to+import+the+yelp_academic_dataset_review.json+into+R&gs_lp=Egxnd3Mtd2l6LXNlcnAiOmhvdyB0byBpbXBvcnQgdGhlIHllbHBfYWNhZGVtaWNfZGF0YXNldF9yZXZpZXcuanNvbiBpbnRvIFIyBRAhGKABMgUQIRigATIFECEYoAEyBRAhGKABMgUQIRigATIFECEYqwIyBRAhGKsCMgUQIRirAkjJDVCoBViBDHABeACQAQCYAeQDoAHrCKoBBzEuNC40LTG4AQPIAQD4AQGYAgegAvsKwgIIEAAY7wUYsAPCAgUQIRifBZgDAIgGAZAGBZIHCTEuNC4xLjAuMaAHjTCyBwkwLjQuMS4wLjG4B9kKwgcDMy03yAdXgAgB&sclient=gws-wiz-serp&mstk=AUtExfAPcvD29NE1gJY6QQvhTk8hSnxSjRjcKLq9_4n9LgSUVG6w6Es3u6JbfNwl0l0HOxW2JOsr4F3YQlbkaTEOk5IigcgCmG17iEYBnwzG3eSKLhiuFrMrv08oIjc8FyzdsEKMRUx7dPhlEgkYgIjEzaMuD5RUGMZ_tI3RVTCdpJxQodzmRDGNxm8JTnPXvDFDQb5aFd8eWGlIEzp1VrNPqy0GPH3BLDNLIBPZpWAsm9Sujjc2aeZLdxiVRA&csuir=1&aioh=3&udm=50#aof=1 

## Selected Restaurant Categories and Geographic System


## Important Tables


## Static Graphs and Maps
<!-- Embed .png, .jpg, or .svg files here using Markdown image syntax. -->


## Main Conclusions and Limitations


## Links to the Code in the Repository
