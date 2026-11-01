#install.packages(c(
#"tidyverse", "jsonlite", "lubridate", "sf", "tigris",
#"scales", "viridis"
#))

library(tidyverse)
library(jsonlite)
library(lubridate)
library(sf)
library(tigris)
library(scales)
library(viridis)
library(vroom)

options(tigris_use_cache = TRUE)

# Define file paths
review_file <- "data/raw/yelp_academic_dataset_review.json"
business_file <- "data/raw/yelp_academic_dataset_business.json"
output_csv  <- "data/raw/yelp_businesses.csv"
output_rds  <- "data/raw/yelp_businesses.rds"

# 1. Read the JSON file directly (since it is small enough to fit in RAM)
# flatten = TRUE automatically unpacks nested lists like attributes and hours
business_df <- fromJSON(sprintf("[%s]", paste(readLines(business_file), collapse = ",")), flatten = TRUE)

# Alternative method if readLines complains about memory on your specific setup:
# business_df <- stream_in(file(input_json), pagesize = 50000, verbose = TRUE)

# 2. Save it as a clean CSV file
# We drop nested lists/dataframes if they cause export issues, or use vroom to write safely
vroom_write(business_df, file = output_csv, delim = ",")

# 3. Save it as a compressed RDS file for rapid R loading
saveRDS(business_df, file = output_rds)
cat("Conversion complete! Created:", output_csv, "and", output_rds)

# 4. Delete yelp_business.csv to free up some space
file.remove("data/raw/yelp_businesses.csv")

business <- business_raw |>
  select(
    business_id, name, address, city, state, postal_code,
    latitude, longitude, stars, review_count, categories
  )

output_csv <- "yelp_reviews_subset.csv"

# Clear the output file if it already exists from a previous run
if (file.exists(output_csv)) file.remove(output_csv)

# 1. Define the callback function to handle each chunk
process_chunk <- function(chunk_df) {
  # Select only your 5 required columns
  subset_df <- chunk_df[, c("review_id", "business_id", "stars", "date", "text")]
  
  # Append this chunk to your clean CSV file
  write.table(subset_df, 
              file = output_csv, 
              append = TRUE, 
              sep = ",", 
              row.names = FALSE, 
              col.names = !file.exists(output_csv), # Only write headers on the first chunk
              qmethod = "double") # Correctly escapes quotes inside the review text
}

# 2. Run the stream in batches of 50,000 rows
stream_in(file(review_file), 
          handler = process_chunk, 
          pagesize = 50000, 
          verbose = TRUE) # Set to TRUE so you can watch the progress


# 1. Load the CSV file quickly using vroom
reviews_df <- vroom("yelp_reviews_subset.csv")

# 2. Save it as an RDS file
saveRDS(reviews_df, file = "data/raw/yelp_reviews_subset.rds")

# 3. Clean up your disk space by deleting the heavy CSV file if you want
file.remove("yelp_reviews_subset.csv")


# Load the saved .rds reviews file
reviews <- readRDS("data/raw/yelp_reviews_subset.rds")

sample_head <- reviews |>
  select(review_id, business_id, stars, date, text) |>
  head(10)

View(sample_head)

dim(business)
dim(reviews)
glimpse(business)
glimpse(reviews)
head(business, 3)