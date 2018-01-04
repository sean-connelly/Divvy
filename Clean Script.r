
library(tidyverse)
library(lubridate)
library(stringr)

user <- Sys.info()[["user"]]
new_wd <- sprintf("C:/Users/%s/Desktop/Divvy/Data/Raw",user)
setwd(new_wd)      
options(scipen = 1000,stringsAsFactors = FALSE)

#=============
#Import Divvy data
#=============

#Download 2016 Divvy zips
sprintf("https://s3.amazonaws.com/divvy-data/tripdata/Divvy_Trips_%s_%s.zip",
        2016,
        c("Q1Q2","Q3Q4")) %>%
  lapply(.,function(x){download.file(x,basename(x))}) %>%
  invisible()

#Unzip
list.files(full.names = TRUE) %>%
  keep(grepl("*.zip",.)) %>%
  lapply(.,function(x){unzip(x,overwrite = TRUE)}) %>%
  invisible()

#Reorganize directory so csvs are in same place, delete subfolder
list.files("./Divvy_Trips_2016_Q1Q2",full.names = TRUE) %>%
  keep(grepl("*.csv",.)) %>% 
  file.copy(from = .,to = ".",
            overwrite = TRUE,copy.mode = TRUE) %>% 
  invisible()

unlink("./Divvy_Trips_2016_Q1Q2",recursive = TRUE)

#=============
#Load and tidy
#=============

#Trips
trips <- dir(".","Trips.*\\.csv",full.names = TRUE) %>% 
  map_df(.,read_csv,progress = FALSE)

#Stations
stations <- dir(".","Stations.*\\.csv",full.names = TRUE) %>% 
  map_df(.,read_csv,progress = FALSE,.id = "sheet")

#Some stations had slight tweaks to long/lat over the time period,
#take the most recent observation
stations <- stations %>% 
  group_by(id) %>%
  top_n(.,1,sheet)

#=============
#Join trips and stations
#=============

#Get rid of problematic duplicate station names in trips
trips <- trips %>%
  select(-matches("station_name"))

#From
trips <- stations %>%
  select(id,"from_station_name" = name,
         "from_long" = longitude,"from_lat" = latitude) %>% 
  left_join(trips,.,by = c("from_station_id" = "id"))
#To
trips <- stations %>%
  select(id,"to_station_name" = name,
         "to_long" = longitude,"to_lat" = latitude) %>% 
  left_join(trips,.,by = c("to_station_id" = "id"))

#=============
#Get rid of dependents, Make datetimes
#=============

trips <- trips %>%
  filter(usertype!="Dependent") %>% 
  mutate(starttime = parse_date_time(starttime,"mdy HMS",
                                     truncated = 1),
         stoptime = parse_date_time(stoptime,"mdy HMS",
                                    truncated = 1))

#=============
#Reorganize into logical order
#=============

trips <- trips %>% 
  select(trip_id,
         "start_time" = starttime,
         "stop_time" = stoptime,
         "bike_id" = bikeid,
         "trip_duration" = tripduration,
         "user_type" = usertype,
         gender,
         "birth_year" = birthyear,
         from_station_id,
         from_station_name,
         from_long,
         from_lat,
         to_station_id,
         to_station_name,
         to_long,
         to_lat)
  
#=============
#Write clean sets to RDS, remove for file size purposes
#=============

# #Sample to mess around with
# trips_sample <- sample_n(trips,100000)
# 
# #Change file location
# data_wd <- sprintf("C:/Users/%s/Desktop/Divvy/Data",user)
# setwd(data_wd)
# 
# #Write
# write_rds(trips,"trips.rds")
# write_rds(trips_sample,"trips_sample.rds")
