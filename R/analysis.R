# Libraries
library(tidyverse)
library(jsonlite)
library(lubridate)
library(sf)
library(tigris)
library(scales)
library(viridis)

# read New Orleans restaurants rds if not already loaded
new_orl_restrs <- readRDS("data/new_orleans/business_new_orleans.rds")
View(new_orl_restrs)

# Extract and inspect individual categories
all_categories <- new_orl_restrs |>
  select(categories) |>
    separate_rows(categories, sep = ",") |>
      mutate(categories = trimws(categories)) |>
        group_by(categories) |>
          summarise(total_count = n()) |>
            arrange(desc(total_count))
View(all_categories)

# Find categories that appear together
# Selected theme: Places where you can get a taste of Orleans Cuisine (local foods like Po' Boys, Gumbos, Jambalaya)
selected_NOLA_businesses <- new_orl_restrs |>
  filter(
    (str_detect(categories, regex("Cajun/Creole", ignore_case=TRUE)) & str_detect(categories, regex("Sandwiches", ignore_case=TRUE))) |
    (str_detect(categories, regex("Cajun/Creole", ignore_case=TRUE)) & str_detect(categories, regex("Seafood", ignore_case=TRUE))) |
    (str_detect(categories, regex("Sandwiches", ignore_case=TRUE)) & str_detect(categories, regex("Seafood", ignore_case=TRUE)))
  )
View(selected_NOLA_businesses)

# save these selected businesses in a rds file
saveRDS(
  selected_NOLA_businesses,
  "data/new_orleans/selected_NOLA_businesses.rds",
  compress = "xz"
)


# read yelp reviews subset rds into R (note: this might take a while)
NOLA_yelp_reviews <- readRDS("data/raw/yelp_reviews_subset.rds")
View(NOLA_yelp_reviews)

# Inner-join the reviews with the selected businesses
selected_NOLA_business_reviews <- selected_NOLA_businesses |>
  inner_join(NOLA_yelp_reviews, by = "business_id")
View(selected_NOLA_business_reviews)

# save the inner-joined business reviews to access easier (only run once)
saveRDS(
  selected_NOLA_business_reviews,
  "data/new_orleans/selected_NOLA_business_reviews.rds",
  compress = "xz"
)





####### (Creating the setup for geographic system maps) ######
# read inner-joined business reviews into R
selected_NOLA_business_reviews <- readRDS("data/new_orleans/selected_NOLA_business_reviews.rds")
View(selected_NOLA_business_reviews)

# read selected businesses (no reviews joined) into R
selected_NOLA_businesses <- readRDS("data/new_orleans/selected_NOLA_businesses.rds")

# Adding an official geographic boundary with a spatial join
louisiana_places <- tigris::places(
  state = "LA",
  cb = TRUE,
  year = 2024,
  class = "sf"
)

restaurant_points <- selected_NOLA_businesses |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(
    coords = c("longitude", "latitude"),
    crs = 4326,
    remove = FALSE
  )

restaurant_points_la <- restaurant_points |>
  st_transform(st_crs(louisiana_places))

restaurants_with_place <- restaurant_points_la |>
  st_join(
    louisiana_places |>
      select(GEOID, place_name = NAME, geometry),
    join = st_within,
    left = TRUE
  )

restaurants_with_place |>
  st_drop_geometry() |>
  count(city, place_name, sort = TRUE)

new_orleans_boundary <- louisiana_places |>
  filter(NAME == "New Orleans")

new_orleans_map_data <- restaurants_with_place |>
  filter(place_name == "New Orleans")

####### (End of Setup) ######

# For each geographic system:
# 1. Convert the Yelp latitude and longitude values into an sf point object
# 2. Use a spatial join to assign each restaurant to an area.
# 3. Count the number of restaurants in each area.
# 4. Calculate the average business rating and, if possible, the reviewer-adjusted rating.
# 5. Check how many restaurants are unmatched or assigned to NA.
# 6. Identify areas with very few restaurants and explain how that affects your conclusions.
# 7. Create at least one map or comparison plot.
# Note: A comparison table must be made (refer to instructions)

###### Geographic system 1 ######
###### Census Tracts ######
NOLA_tracts <- tracts(state = "LA", county = "Orleans", cb = TRUE)
View(NOLA_tracts)

restaurant_points_tr <- restaurant_points |>
  st_transform(st_crs(NOLA_tracts))

restaurants_with_tract <- restaurant_points_tr |>
  st_join(
    NOLA_tracts |>
      select(GEOID, tract_name = NAME),
    join = st_within,
    left = TRUE
  )
View(restaurants_with_tract)

# Gets number of tracts
restaurants_with_tract |>
  filter(!is.na(tract_name)) |>
  group_by(tract_name) |>
  summarise(
    num_restaurants_in_tract = n()
  ) |>
  st_drop_geometry()

# Gets number of restaurants assigned
restaurants_with_tract |>
  filter(!is.na(tract_name)) |>
  summarise(
    total_restaurants_assigned = n()
  ) |>
  st_drop_geometry()

# Calculates average business rating per tract (sorted by highest average rating)
restaurants_with_tract |>
  filter(!is.na(tract_name)) |>
  group_by(tract_name) |>
  summarise(
    avg_rating = mean(stars, na.rm = TRUE),
    total_restaurants = n()
  ) |>
  arrange(desc(avg_rating)) |>
  st_drop_geometry()

# Find census tracts with very few restaurants (ordered from least restaurants to most restaurants)
restaurants_across_tracts <- restaurants_with_tract |>
  filter(!is.na(tract_name)) |>
  group_by(tract_name) |>
  summarise(
    total_restaurants_in_tract = n()
  ) |>
  arrange(total_restaurants_in_tract) |>
  st_drop_geometry()
View(restaurants_across_tracts)
write.csv(restaurants_across_tracts, "figures/fewest_rests_within_ctracts.csv")

# Create a map of restaurant points with census tracts
ggplot() +
  geom_sf(data = NOLA_tracts, color = "darkgray", size = 0.1) +
  geom_sf(data = new_orleans_map_data, aes(color = stars), alpha = 0.85, size = 0.85) +
  scale_color_viridis_c(option = "C", limits = c(1, 5)) +
  labs(
    title = "Selected New Orleans Restaurants Within Census Tracts"
  ) +
  theme_minimal()
############
############

####### Geographic system 2 ######
####### Census Block Groups ######
NOLA_block_groups <- block_groups(state = "LA", county = "Orleans")
View(NOLA_block_groups)

restaurant_points_bgs <- restaurant_points |>
  st_transform(st_crs(NOLA_block_groups))

restaurants_with_block_groups <- restaurant_points_bgs |>
  st_join(
    NOLA_block_groups |>
      select(GEOID, block_group_name = BLKGRPCE),
    join = st_within,
    left = TRUE
  )
View(restaurants_with_block_groups)

# Gets number of block groups
restaurants_with_block_groups |>
  filter(!is.na(block_group_name)) |>
  group_by(block_group_name) |>
  summarise(
    total_restaurants_in_bg = n()
  ) |>
  st_drop_geometry()

# Gets number of assigned restaurants
restaurants_with_block_groups |>
  filter(!is.na(block_group_name)) |>
  summarise(
    total_restaurants_assigned = n()
  ) |>
  st_drop_geometry()

# Gets the number of restaurants unassigned (block_group_name = NA)
restaurants_with_block_groups |>
  filter(is.na(block_group_name)) |>
  summarise(
    total_restaurants_unassigned = n()
  ) |>
  st_drop_geometry()

# Calculates average business rating per block group
restaurants_with_block_groups |>
  filter(!is.na(block_group_name)) |>
  group_by(block_group_name) |>
  summarise(
    avg_rating = mean(stars, na.rm = TRUE),
    restaurants_in_bg = n()
  ) |>
  st_drop_geometry()

# Find census block groups with very few restaurants
restaurants_across_bgs <- restaurants_with_block_groups |>
  filter(!is.na(block_group_name)) |>
  group_by(block_group_name) |>
  summarise(
    total_restaurants_in_bg = n()
  ) |>
  arrange(total_restaurants_in_bg) |>
  st_drop_geometry()
View(restaurants_across_bgs)

# Create a map of restaurant points with census block groups
ggplot() +
  geom_sf(data = NOLA_block_groups, aes(fill = BLKGRPCE), size = 0.1) +
  geom_sf(data = new_orleans_map_data,aes(color = stars), alpha = 1, size = 1.5) +
  scale_color_viridis_c(option = "C", limits = c(1, 5)) +
  labs(
    title = "Selected New Orleans Restaurants Within Census Block Groups"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 12),
    legend.position = "bottom",
    legend.direction = "horizontal"
  )
############
############