import math
import requests
from bs4 import BeautifulSoup
import csv
import time
# save the time when the script began executing
start_time = time.time()
# we will write to the .csv file
# define its headers that will be populated by this script
column_names = ["Listing Link","Listing ID","Seller ID","Seller Name","Listed Price","Zip Code","State","Boat Type","Length","Year Built","Manufacturer","Engine Type","Engine Power","Fuel Type"]
# create new or open .csv file
output_file = open("boattrader output.csv", "w", newline="")
# instantiate the csv writer
csvwriter = csv.DictWriter(output_file, delimiter=",", fieldnames=column_names)
# write the header
csvwriter.writeheader()

# here's the approach to web scraping:
# boattrader.com doesn't return more than ~10,000 records at a time, despite the search result saying otherwise. 
# that means that we need to break our search query into multiple requests and combine the results
# we are going to define the list of search URLs, each one is tailored to return around 10,000 records
# each url will be sent to the web site twice: asking for search results to be sorted by Listing Update Time in ascending then descending order
# each time we're going to scrape either first 160 pages of the number of pages in result (if the number of pages returned is less than 175)
# since boattrader.com returns 28 results per page, max number of pages available to scrape is ~358, so we just take a little less than half of that
# because we are going to scrape each one twice we are expecting to hit top updated 160 pages then hit last updated 160
# there could be duplicates depending on the number of listings returned, but they'll be cleaned in R
# (expected number of listings to inspect is 2*160*28 ~ 9000)

# define list of url's to search and then append url's of interest to it
# note that URLs were picked manually trying to achieve aproximately 9-10k returned results
url_list = []
# Pacific Market: 95814 is downtown Sacramento
base_url = "https://www.boattrader.com/boats/zip-95814/radius-1000/"
url_list.append(base_url)
# Great Lakes Market: 60601 is downtown Chicago
base_url = "https://www.boattrader.com/boats/zip-60601/radius-220/"
url_list.append(base_url)
# North East Market: 10004 is downtown New York
base_url = "https://www.boattrader.com/boats/zip-10004/radius-200/"
url_list.append(base_url)
# South East Market: 32202 is downtown Jacksonville (this one is different, since Florida market is so dense, this query produces ~40k records
# but sorting by date rather than distance allows for better sampling per state and in the end a more represented South East market)
base_url = "https://www.boattrader.com/boats/zip-32202/radius-500/"
url_list.append(base_url)
# next query increases the size of "Other" region as well as Great Lakes and potentially North/South East since search radius is so great (however, they could be duplicates)
# 64101 - Kansas City
base_url = "https://www.boattrader.com/boats/zip-64101/radius-1000/"
url_list.append(base_url)
# this search is to A) try and get more records in the Pacific region B) get more listings in the states that border Pacific states
# 84044 - Salt Lake City
base_url = "https://www.boattrader.com/boats/zip-84044/radius-600/"
url_list.append(base_url)
# Get more records for Florida and South East in General since the Region is so dense with listings and search around Jacksoville proved to produce less FL records than we desired
# search 500 miles around Orlando, this should give us a good sample for South East (note that Jacksonville search yields lots of "Other" and even some "North East" records)
base_url = "https://www.boattrader.com/boats/zip-32819/radius-500/"
url_list.append(base_url)


# these are sort conditions we will append to url:
# sort_distance = "sort-distance:asc/" # sort from closest to farthest (not applicable in this iteration of the script)
sort_updated_desc = "sort-updated:desc/" #newest first
sort_updated_asc = "sort-updated:asc/"  #oldest first
# we will throw these conditions in the list, and then loop through this list for each url:
condition_list = []
condition_list.append(sort_updated_asc)
condition_list.append(sort_updated_desc)

# counter var will keep track of the number of listings written to the output file
counter = 0

# now loop through each url and do a thorough web scraping:
for base_url in url_list:
    # per logic defined above, each url needs first be sorted by updated date in ascending then in descending order:
    for sort_condition in condition_list:
        # append sort condition to the base url - resulting search url will be used for the initial search request
        search_url = base_url + sort_condition
        print("base search page is set to:")
        print(search_url)
        # make a web request, then calculate number of web pages with listings returned based on the value in <div class="results-count"></div>
        search_return = requests.get(search_url)
        if search_return.status_code == 200:
            raw_html = search_return.text
            soup = BeautifulSoup(raw_html, 'html.parser')
            # find the number of listings returned, should be something like "Viewing 1 - 28 of 4,850"
            results_count_div =  soup.find('div',{'class': 'results-count'})
            # get text content of this div
            results_count_text = results_count_div.text
            # remove possible comma separator, then split using space, then use last item in the resulting list to get the total number of results returned
            results_count_list = results_count_text.replace(',', '').split(' ')
            results_count = results_count_list[len(results_count_list)-1]
            # 28 results per page, use ceiling function to do the division and get page count to scrape
            page_count = math.ceil(int(results_count)/28)
            # print the summary out
            print("results set has page count equal to %s"%page_count+" (%s"%results_count+" listings)")
            # now determine if we will look at 160 (as defined before) or less (if num pages is <160)
            # just overwrite page_count if it's greater than 160
            if page_count > 160:
                page_count = 160
            # show how many pages this script will go through:
            print("will iterate through %s"%page_count+" pages...") 
            # loop through each page of results
            for page in range(1, page_count):
                # build new url to make request to. print to the screen to alert the users
                page_url = base_url + "page-%s"%page+"/" + sort_condition
                print("scraping page %s"%page+" now. url has been set to:")
                print(page_url)
                print("working on the following url's from this page:")
                # make request, parse html
                result = requests.get(page_url)
                if result.status_code == 200:
                    raw_html = result.text
                    soup = BeautifulSoup(raw_html, "html.parser")
                    # find all links <a> to the listings on the current page (look for both standard and enhanced listings)
                    listings_links = soup.find_all("a", {"data-reporting-click-listing-type": ['standard listing', 'enhanced listing'] })
                    # loop through them and get data on each individual listing page
                    # note that there's three (3) <a> elements for each listing, so the range loop will use a step of 3
                    for i in range(0, len(listings_links), 3):
                        # print the url of the page you're going to scrape next
                        print(listings_links[i]["href"])
                        # request and parse this listing web page (only if OK returned)
                        listing_result = requests.get(listings_links[i]["href"])
                        if listing_result.status_code == 200:
                            listing_html = listing_result.text
                            listing_soup = BeautifulSoup(listing_html, "html.parser")
                            # make sure that the page returned is a listing page 
                            # noticed that sometimes you're redirected to https://www.boattrader.com/browse/
                            # probably if a listing has been taken down
                            check = listing_soup.find("h1",{"class": "bd-name"})
                            if check is not None:
                                # define new dictionary to hold data for this listing (then to be written in the .csv file)
                                listing_data = {}
                                # append the listing link to the dictionary
                                listing_data["Listing Link"] = listings_links[i]["href"]
                                # turns out that price in numeric format as well as some other needed info is found in one of the <script> tags (it has var product id json type of var)
                                script_tags = listing_soup.find_all('script',  type="text/javascript")
                                # loop through them, look for "var product =" in the text - this is the one we need!
                                for j in range(len(script_tags)):
                                    # check if this is the one
                                    if "var product" in script_tags[j].text:
                                        temp = script_tags[j].text
                                        # remove all white space
                                        temp = "".join(temp.split())
                                        # remove substrings from left and right of the string
                                        temp = temp.replace("varproduct={", "").replace("};", "")
                                        # split using comma and only then search for specific values
                                        temp = temp.split(',')
                                        # this will leave us with a list of strings looking something like this: 
                                        # ['imtID:"7228301"', 'productClass:"CenterConsoles"', 'manufacturer:"Everglades"', 
                                        # 'length:"23"', 'state:"CA"', 'category:"boat"', 'city:"HuntingtonPark"', 'country:"US"', 
                                        # 'listedPrice:"79000"', 'model:"230CenterConsole"', 'yearBuilt:"2016"', 
                                        # 'productType:"power"', 'sellerID:"258457"']
                                        # now loop through this list and get the values we need (strip "" before appending)
                                        for k in temp:
                                            k = k.split(':')
                                            # listing ID
                                            if k[0] == "imtID":
                                                listing_data["Listing ID"] = k[1].replace('"', '')
                                            elif k[0] == "sellerID":
                                                listing_data["Seller ID"] = k[1].replace('"', '')
                                            elif k[0] == "listedPrice":
                                                listing_data["Listed Price"] = k[1].replace('"', '')
                                            elif k[0] == "length":
                                                listing_data["Length"] = k[1].replace('"', '')
                                            elif k[0] == "yearBuilt":
                                                listing_data["Year Built"] = k[1].replace('"', '')
                                            elif k[0] == "state":
                                                listing_data["State"] = k[1].replace('"', '')
                                            elif k[0] == "manufacturer":
                                                listing_data["Manufacturer"] = k[1].replace('"', '')
                                            elif k[0] == "productType":
                                                listing_data["Boat Type"] = k[1].replace('"', '')
                                    # get seller name and parse as text (make sure element was found first)
                                    seller_name = listing_soup.find(id="seller-name")
                                    if seller_name is not None:
                                        seller_name = seller_name.text
                                    else:
                                        seller_name = "NA"
                                    # add to the dictionary
                                    listing_data["Seller Name"] = seller_name
                                    # get the zip code (and do the same approach as with seller_name)
                                    zip_code = listing_soup.find("span",{"class": "postal-code"})
                                    if zip_code is not None:
                                        zip_code = zip_code.text
                                    else:
                                        zip_code = "NA"
                                    # add to the dictionary
                                    listing_data["Zip Code"] = zip_code
                                    # finally, there are some additional details about engine that can be gathered from "Propulsion" panel
                                    engine_details = listing_soup.find_all('tr')
                                    # set up boolean flags to keep track of engine info that was found and appended (they aren't always available)
                                    engine_type_found = False
                                    engine_power_found = False
                                    fuel_found = False
                                    # go though engine details <tr>s and set flag to True if something is found
                                    for j in range(len(engine_details)):
                                        if engine_details[j].text.strip("\n")[0:11] == "Engine Type":
                                            listing_data["Engine Type"] = engine_details[j].text.strip("\n")[12:]
                                            engine_type_found = True
                                        elif engine_details[j].text.strip("\n")[0:11] == "Total Power":
                                            # make sure value written to the .csv output is numeric
                                            hp = engine_details[j].text.strip("\n")[12:]
                                            # first, try removing "hp" from the string:
                                            horse_power = hp.replace("hp","")
                                            # second, make sure the result is a number (int)
                                            if horse_power.isdigit():
                                                listing_data["Engine Power"] = horse_power
                                                engine_power_found = True
                                        elif engine_details[j].text.strip("\n")[0:9] == "Fuel Type":
                                            listing_data["Fuel Type"] = engine_details[j].text.strip("\n")[10:]
                                            fuel_found = True
                                    # check if any engine details weren't found - add "NA" in that case
                                    if not engine_type_found:
                                        listing_data["Engine Type"] = "NA"
                                    if not engine_power_found:
                                        listing_data["Engine Power"] = "NA"
                                    if not fuel_found:
                                        listing_data["Fuel Type"] = "NA"
                                # write to the output file only if price is disclosed ("Requestaprice" means no price was disclosed)
                                # assign csvwriter.writerow() to a dummy var _ in order to supress return of written character count
                                if listing_data["Listed Price"] != "Requestaprice":
                                    _ = csvwriter.writerow({"Listing Link": listing_data["Listing Link"], "Listing ID": listing_data["Listing ID"], "Seller ID": listing_data["Seller ID"], "Seller Name": listing_data["Seller Name"], "Listed Price": listing_data["Listed Price"], "Zip Code": listing_data["Zip Code"], "State": listing_data["State"], "Boat Type": listing_data["Boat Type"], "Length": listing_data["Length"], "Year Built": listing_data["Year Built"], "Manufacturer": listing_data["Manufacturer"], "Engine Type": listing_data["Engine Type"], "Engine Power": listing_data["Engine Power"], "Fuel Type": listing_data["Fuel Type"]})
                                    # increment the written listing counter
                                    counter = counter + 1
                                # flush buffer every 100 written listings, reset the counter
                                if counter >= 100:
                                    print("flushing the buffer...")
                                    output_file.flush()
                                    counter = 0

# close the file, we're done
output_file.close()
# show execution time to the user
print("execution time: %s seconds..." % round((time.time() - start_time), 2))