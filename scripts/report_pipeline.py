import json, os, itertools, math, urllib.request
from pathlib import Path
import pandas as pd
import numpy as np
import geopandas as gpd
import matplotlib.pyplot as plt
import seaborn as sns

BASE = Path('/workspace/scratch/7cd1ca20c11e')
RAW = BASE / 'yelp_raw'
OUT = BASE / 'report_output'
FIG = OUT / 'figures'
TAB = OUT / 'tables'
FIG.mkdir(parents=True, exist_ok=True); TAB.mkdir(parents=True, exist_ok=True)
sns.set_theme(style='whitegrid', context='notebook')

def esc(s):
    return (str(s).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;'))

def read_json_lines(path):
    return pd.read_json(path, lines=True)

# Import and clean businesses, following import.R and clean.R.
business = read_json_lines(RAW/'yelp_academic_dataset_business.json')
business = business[['business_id','name','address','city','state','postal_code','latitude','longitude','stars','review_count','categories']].copy()
business['categories'] = business['categories'].fillna('')
nola_restaurants = business[
    business.state.eq('LA') & business.city.eq('New Orleans') &
    business.categories.str.contains('Restaurants', case=False, na=False)
].drop_duplicates('business_id').copy()
nola_restaurants['business_name'] = nola_restaurants['name'].str.replace(r'\\s+', ' ', regex=True).str.strip()

selected = ['Cajun/Creole','Sandwiches','Seafood']
patterns = [r'(?i)(^|,\\s*)'+x.replace('/','/')+r'(,|$)' for x in selected]
mask = pd.Series(False, index=nola_restaurants.index)
for p in patterns: mask |= nola_restaurants.categories.str.contains(p, regex=True, na=False)
selected_businesses = nola_restaurants[mask].copy()
selected_ids = set(selected_businesses.business_id)

# Category counts and pair counts.
cat_rows=[]
for _, r in nola_restaurants[['business_id','categories']].iterrows():
    for c in r.categories.split(','):
        c=c.strip()
        if c: cat_rows.append((r.business_id,c))
cat_long = pd.DataFrame(cat_rows, columns=['business_id','category'])
category_counts = cat_long.category.value_counts().rename_axis('category').reset_index(name='restaurants')
pair_rows=[]
for bid, grp in cat_long.groupby('business_id'):
    cats=sorted(set(grp.category))
    pair_rows += [(a,b) for a,b in itertools.combinations(cats,2)]
pairs = pd.DataFrame(pair_rows, columns=['category_1','category_2']).value_counts().rename('cooccurrences').reset_index().sort_values('cooccurrences', ascending=False)
category_counts.head(20).to_csv(TAB/'category_counts.csv', index=False)
pairs.head(20).to_csv(TAB/'category_pairs.csv', index=False)

# Stream all reviews and retain only reviews for selected businesses.
review_path = RAW/'yelp_academic_dataset_review.json'
review_rows=[]
with open(review_path, encoding='utf-8') as f:
    for line in f:
        obj=json.loads(line)
        if obj.get('business_id') in selected_ids:
            review_rows.append({k:obj.get(k) for k in ['business_id','user_id','stars','date','useful','funny','cool']})
reviews=pd.DataFrame(review_rows)
reviews['date']=pd.to_datetime(reviews['date'], errors='coerce')
reviews.to_csv(TAB/'selected_reviews.csv', index=False)

# Official Census TIGER/Line cartographic boundaries; equivalent purpose to tigris in analysis.R.
def get_zip(url, name):
    p=OUT/name
    if not p.exists(): urllib.request.urlretrieve(url, p)
    return p
tract_zip=get_zip('https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_22_tract_500k.zip','tracts.zip')
bg_zip=get_zip('https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_22_bg_500k.zip','block_groups.zip')
place_zip=get_zip('https://www2.census.gov/geo/tiger/GENZ2024/shp/cb_2024_22_place_500k.zip','places.zip')
tracts=gpd.read_file('zip://'+str(tract_zip)).query("COUNTYFP == '071'")
blocks=gpd.read_file('zip://'+str(bg_zip)).query("COUNTYFP == '071'")
places=gpd.read_file('zip://'+str(place_zip))
new_orleans_boundary=places[places.NAME.eq('New Orleans')]
points=gpd.GeoDataFrame(selected_businesses, geometry=gpd.points_from_xy(selected_businesses.longitude, selected_businesses.latitude), crs='EPSG:4326')
points=points[~points.geometry.is_empty & points.geometry.notna()].copy()
points_tract=gpd.sjoin(points, tracts[['GEOID','geometry']], how='left', predicate='within').drop(columns=['index_right'])
points_block=gpd.sjoin(points, blocks[['GEOID','geometry']], how='left', predicate='within').drop(columns=['index_right'])
points_tract.rename(columns={'GEOID':'tract_geoid'}, inplace=True); points_block.rename(columns={'GEOID':'block_group_geoid'}, inplace=True)
selected_businesses=selected_businesses.merge(points_tract[['business_id','tract_geoid']], on='business_id', how='left').merge(points_block[['business_id','block_group_geoid']], on='business_id', how='left')

# Reviewer-level normalization, following analysis.R.
reviews=reviews.merge(selected_businesses[['business_id','business_name','stars_y' if 'stars_y' in selected_businesses else 'stars']], on='business_id', how='left', suffixes=('','_business'))
reviews['reviewer_activity']=reviews.groupby('user_id')['business_id'].transform('size')
reviews['reviewer_mean']=reviews.groupby('user_id')['stars'].transform('mean')
reviews['normalized_score']=reviews['stars']-reviews['reviewer_mean']
eligible=reviews[reviews.reviewer_activity>=5].copy()
all_summary=reviews.groupby('business_id').agg(number_of_reviews_all_reviewers=('stars','size'), average_stars_all_reviewers=('stars','mean'), median_stars_all_reviewers=('stars','median')).reset_index()
adj_summary=eligible.groupby('business_id').agg(number_of_reviews_eligible_reviewers=('stars','size'), average_stars_eligible_reviewers=('stars','mean'), average_normalized_score=('normalized_score','mean'), median_normalized_score=('normalized_score','median')).reset_index()
restaurant_summary=selected_businesses[['business_id','business_name','stars','review_count','tract_geoid','block_group_geoid']].merge(all_summary,on='business_id',how='left').merge(adj_summary,on='business_id',how='left')
restaurant_summary.sort_values('average_normalized_score', ascending=False).to_csv(TAB/'restaurant_summary.csv', index=False)

def area_summary(key):
    a=restaurant_summary.dropna(subset=[key]).groupby(key).agg(restaurants=('business_id','nunique'), avg_business_rating=('stars','mean'), total_yelp_reviews=('review_count','sum'), avg_raw_review_score=('average_stars_all_reviewers','mean'), avg_normalized_score=('average_normalized_score','mean')).reset_index()
    return a.sort_values(['avg_normalized_score','avg_business_rating'], ascending=False)
tract_summary=area_summary('tract_geoid'); block_summary=area_summary('block_group_geoid')
tract_summary.to_csv(TAB/'tract_summary.csv', index=False); block_summary.to_csv(TAB/'block_group_summary.csv', index=False)

# Plots.
plt.figure(figsize=(10,5)); sns.barplot(data=category_counts.head(15), y='category', x='restaurants', color='#e45756'); plt.title('Most common categories among New Orleans restaurants'); plt.xlabel('Number of businesses'); plt.ylabel(''); plt.tight_layout(); plt.savefig(FIG/'category_counts.png', dpi=180); plt.close()
area_plot=tract_summary[tract_summary.restaurants>=5].head(12).copy(); area_plot['tract_geoid']=area_plot.tract_geoid.astype(str)
plt.figure(figsize=(10,6)); sns.barplot(data=area_plot, y='tract_geoid', x='avg_normalized_score', color='#2a9d8f'); plt.axvline(0,color='grey',lw=1); plt.title('Reviewer-adjusted scores by census tract (minimum 5 businesses)'); plt.xlabel('Mean normalized review score'); plt.ylabel('Census tract GEOID'); plt.tight_layout(); plt.savefig(FIG/'tract_adjusted_scores.png', dpi=180); plt.close()
plt.figure(figsize=(7,6)); sns.scatterplot(data=restaurant_summary, x='average_stars_all_reviewers', y='average_normalized_score', size='number_of_reviews_all_reviewers', hue='stars', palette='viridis', sizes=(30,300), alpha=.75); plt.axhline(0,color='grey',lw=1); plt.title('Raw ratings versus reviewer-adjusted scores'); plt.xlabel('Average stars from all reviewers'); plt.ylabel('Average normalized score'); plt.legend(bbox_to_anchor=(1.02,1), loc='upper left', fontsize=8); plt.tight_layout(); plt.savefig(FIG/'raw_vs_adjusted.png', dpi=180); plt.close()
ax=new_orleans_boundary.plot(figsize=(8,8), color='#f1f1f1', edgecolor='#444444', linewidth=.8); points.plot(ax=ax, column='stars', cmap='viridis', markersize=18, alpha=.8, legend=True); ax.set_title('Selected restaurants in the New Orleans Census place boundary'); ax.set_axis_off(); plt.tight_layout(); plt.savefig(FIG/'restaurant_map.png', dpi=180); plt.close()

metrics={
 'businesses_total':int(len(business)), 'nola_restaurants':int(len(nola_restaurants)), 'selected_businesses':int(len(selected_businesses)), 'selected_reviews':int(len(reviews)), 'eligible_reviewers':int(eligible.user_id.nunique()), 'tracts_with_businesses':int(restaurant_summary.tract_geoid.nunique()), 'block_groups_with_businesses':int(restaurant_summary.block_group_geoid.nunique()), 'missing_coordinates':int(selected_businesses[['latitude','longitude']].isna().any(axis=1).sum()), 'unmatched_tracts':int(restaurant_summary.tract_geoid.isna().sum()), 'unmatched_block_groups':int(restaurant_summary.block_group_geoid.isna().sum())
}
json.dump(metrics, open(OUT/'metrics.json','w'), indent=2)
print(json.dumps(metrics, indent=2))
