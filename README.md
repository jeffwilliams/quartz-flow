QuartzFlow -- A Web-based Bittorrent Client
===========================================

A Web-based Bittorrent client. 

QuartzFlow runs as a standalone application which contains a web-server. For those familiar with ruby, it uses Sinatra
to run as a webserver.


Installation
------------

`gem install quartz_flow`

Running
-------

### Quick Start

  1. Make a directory owned by the current user where you want QuartzFlow to run.
  2. Run `quartzflow setup` to set up the current directory.
  3. Run `quartzflow adduser --login someone` to add a user named `someone` (replace someone with a good username).
  4. Run `quartzflow start` or just `quartzflow` to run QuartzFlow.
  5. Open `localhost:4445/` with your browser and log in.
  6. When finished use CTRL-C to exit.
  7. (Optional) Edit `etc/quartz.rb` and change settings if desired. Restart after changes.

### Details

QuartzFlow expects to be run in a special "home" directory. This is a regular directory that has 
had `quartzflow setup` run in it; that is, the command is run with the current directory being the directory to set up.
This setup creates the necessary environment needed for QuartzTorrent to run. It creates the required subdirectories, 
copies the HTML templates, creates an empty settings database, and creates default settings files. 
This setup only needs to be performed once per home, and from then on QuartzTorrent can 
be launched from that directory.

A successfully setup QuartzTorrent home directory contains the following:

`etc/`

Static settings. These are things like what port to listen on, and how to log messages.

`db/`       

Dynamic settings. Under this directory is a SQLite database used to store settings that can be changed 
through the webpage.

`log/`      

Logs. By default, logs about torrent downloading and uploading are written here.

`public/, views/`   

Web files. These are the HTML templates, Javascript files, and CSS served when the app is running.

`meta/`     

Torrent metainformation. This is where downloaded and uploaded .torrent files are stored, and where Magnet
links are persisted.

`download/`

Downloaded Torrents. By default, downloaded torrent data is written to this directory.

Use the command `quartzflow help` to get help for the various commands.

`plugins/`

Active quartzflow plugins. 
