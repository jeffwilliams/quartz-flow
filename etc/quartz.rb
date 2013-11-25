# Quartzflow config file.

# IP address that the web server should bind to
set :bind, "0.0.0.0"

# TCP port that the web server should bind to
set :port, 4444

# Directory where downloaded torrent data will be stored
set :basedir, "download" 

# Directory where .torrent files and .info files will be stored.
set :metadir, "meta" 

# TCP port used for torrents
set :torrent_port, 9996

# SQLite database used for storing settings and state
set :db_file, "db/quartz.sqlite"

# Where to log torrent protocol messages
set :torrent_log, "log/torrent.log"

# On which day of the month should monthly usage tracking reset
set :monthly_usage_reset_day, 5

# Torrent Queueing settings. 
# Max number of active torrents is the max number of torrents that can be running at once.
# Max number of incomplete torrents is a subset of the max active torrents, and describes
# the max number of torrents that can be running that are not uploading.
set :torrent_queue_max_active, 10
set :torrent_queue_max_incomplete, 5
