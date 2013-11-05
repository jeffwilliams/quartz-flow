
/* Main Angular module */
var quartzModule = angular.module('quartz',[]);

/* Set up URL routes. Different URLs map to different HTML fragments (templates)*/
quartzModule.config(function($routeProvider) {
  $routeProvider.
    when('/', {controller: TorrentTableCtrl, templateUrl:'/torrent_table'}).
    when('/details/:torrent', {controller: TorrentDetailsCtrl, templateUrl:'/torrent_detail'}).
    when('/config', {controller: ConfigCtrl, templateUrl:'/config'}).
    otherwise({redirectTo:'/'});

});

/* Set up function that keeps retrieving torrent data from server on a timer.
   We store the data in the rootScope which means it's available in all scopes. */
quartzModule.run(function($rootScope, $timeout, $http) {
  $rootScope.alerts = {};

  $rootScope.deleteRootscopeError = function(err){
    delete $rootScope.alerts[err];
  }

  $rootScope.rootErrors = function() {
    var rc = [];
    for (var key in $rootScope.alerts) {
      if ($rootScope.alerts.hasOwnProperty(key)) {
        rc.push(key);
      }
    }
    
    return rc;
  };

});

/* Controller for the torrent table view */
function TorrentTableCtrl($scope, $rootScope, $timeout, $http, $window) {
  $scope.errors = [];
  $scope.destroyed = false;

  $scope.$on("$destroy", function(e){
    console.log("Destroy called for TorrentTableCtrl");
    $scope.destroyed = true;
  });
  console.log("TorrentTableCtrl called");

  // Load the list of torrent data every 1 second.
  var refresh = function() {
    // http://code.angularjs.org/1.0.8/docs/api/ng.$http

    var msg = "Server is unreachable.";
    var fields = ["recommendedName", "dataLength", "infoHash", "downloadRate", "uploadRate","percentComplete","timeLeft"]
    $http.get("/torrent_data", {'timeout': 3000, "params": {"fields" : fields } }).
      success(function(data,status,headers,config){
        $rootScope.torrents = data;
        updateTableTorrentData($rootScope);
        $rootScope.deleteRootscopeError(msg);
      }).
      error(function(data,status,headers,config){
        $rootScope.torrents = [];
        updateTableTorrentData($rootScope);
        if ( status == 0 ){
          $rootScope.alerts[msg] = 1;
        } else if (data == "Authentication required" ) {
          $window.location.href = '/login';
        } else {
          $rootScope.alerts[data] = 1;
        }
      });

    if ( ! $scope.destroyed ){
      $timeout(refresh, 1000);
    }
  }
  refresh();

  var checkIframeMessages = function() {
    while( iframeUploadResultMessages.length > 0 ) {
      var msg = iframeUploadResultMessages.shift();
      if ( msg != "@@success" ){
        $scope.errors.push(msg);
      }
    }

    if ( ! $scope.destroyed ){
      $timeout(checkIframeMessages, 1000);
    }
  }
  $timeout(checkIframeMessages, 1000);

  $scope.deleteError = function(err){
    genericDeleteError($scope, err);
  }

  $scope.dailyUsage = 0;
  $scope.monthlyUsage = 0;
  // Load the usage values
  var getUsage = function() {
    $http.get("/usage", {'timeout': 3000}).
      success(function(data,status,headers,config){
        $scope.dailyUsage = data.dailyUsage;
        $scope.monthlyUsage = data.monthlyUsage;
      })

    if ( ! $scope.destroyed ){
      $timeout(getUsage, 2000);
    }
  }
  getUsage();

  $scope.getTimes = function(n){
    var result = [];
    for(var i = 0; i < n; i++){
      result.push(i);
    }
    return result;
  }

  $scope.setPage = function(n){
    $scope.currentPageIndex = n - 1;
    if ( $scope.currentPageIndex < 0 )
      $scope.currentPageIndex = 0;
    if ( $scope.currentPageIndex >= $scope.totalPages )
      $scope.currentPageIndex = $scope.totalPages - 1;
    updatePages($scope);
    updatePagesInfo($scope);
  }

  $scope.decrementPage = function(){
    $scope.setPage($scope.currentPageIndex);
  }

  $scope.incrementPage = function(){
    $scope.setPage($scope.currentPageIndex+2);
  }

  $scope.torrentToDownload = "";
  $scope.magnetToStart = "";

  $scope.downloadTorrentFile = function(){
    $http.post("/download_torrent", {"url": $scope.torrentToDownload}).
      success(function(data,status,headers,config){
        console.log("huzzah, downloading torrent succeeded");
      }).
      error(function(data,status,headers,config){
        console.log("Crap, downloading torrent failed: " + status + ": " + data);
        $scope.errors.push(data);
      });
  }

  $scope.startMagnetLink = function(){
    $http.post("/start_magnet", {"url": $scope.magnetToStart}).
      success(function(data,status,headers,config){
        console.log("huzzah, starting magnet succeeded");
      }).
      error(function(data,status,headers,config){
        console.log("Crap, starting magnet failed: " + status + ": " + data);
        $scope.errors.push(data);
      });
  }
  
  $scope.stateForDisplay = function(infoHash){
    var torrent = $scope.torrents[infoHash];
    if ( ! torrent ){
      return "unknown";      
    }

    var result = torrent.state;

    if ( torrent.paused ){
      result = result + " (paused)";
    }

    return result;
  }
  
  $scope.pauseMenuItem = function(infoHash){
    var torrent = $scope.torrents[infoHash];
    if ( ! torrent ) {
      return "Pause";
    }
    var rc = ""
    if (torrent.paused) {
      rc = "Unpause";
    } else {
      rc = "Pause";
    }
    return rc; 
  }

  $scope.togglePause = function(infoHash){
    var torrent = $scope.torrents[infoHash];
    if ( ! torrent ) {
      return;
    }
    var url = "";
    if (torrent.paused) {
      url = "/unpause_torrent";
    } else {
      url = "/pause_torrent";
    }

    $http.post(url, {"infohash": infoHash}).
      success(function(data,status,headers,config){
        console.log("huzzah, unpausing torrent succeeded");
      }).
      error(function(data,status,headers,config){
        console.log("Crap, unpausing torrent failed: " + status + ": " + data);
        $scope.errors.push(data);
      });
  }
  
  $scope.deleteTorrent = function(infoHash, deleteFiles){
    var torrent = $scope.torrents[infoHash];
    if ( ! torrent ) {
      return;
    }
   
    $http.post("/delete_torrent", {"infohash": infoHash, "delete_files": deleteFiles}).
      success(function(data,status,headers,config){
        console.log("huzzah, deleting torrent succeeded");
      }).
      error(function(data,status,headers,config){
        console.log("Crap, deleting torrent failed: " + status + ": " + data);
        $scope.errors.push(data);
      });
  }


}

/* Controller for the torrent details view */
function TorrentDetailsCtrl($scope, $rootScope, $timeout, $routeParams, $http, $window) {
  $scope.destroyed = false;

  $scope.$on("$destroy", function(e){
    console.log("Destroy called for TorrentDetailsCtrl");
    $scope.destroyed = true;
  });

  // Load the list of torrent data every 1 second.
  var refresh = function() {
    // http://code.angularjs.org/1.0.8/docs/api/ng.$http

    var msg = "Server is unreachable.";
    $http.get("/torrent_data", {'timeout': 3000, "params": {"where" : {"infoHash" : $routeParams.torrent} } }).
      success(function(data,status,headers,config){
        $scope.torrent = data[$routeParams.torrent]
        $rootScope.deleteRootscopeError(msg);
      }).
      error(function(data,status,headers,config){
        $scope.torrent = null
        if ( status == 0 ){
          $rootScope.alerts[msg] = 1;
        } else if (data == "Authentication required" ) {
          $window.location.href = '/login';
        } else {
          $rootScope.alerts[data] = 1;
        }
      });

    if ( ! $scope.destroyed ){
      $timeout(refresh, 1000);
    }
  }
  refresh();

  $scope.deleteError = function(err){
    genericDeleteError($scope, err);
  }

  $scope.applyDownloadRateLimit = function(){
    $http.post("/change_torrent", {"infoHash": $scope.torrent.infoHash, "downloadRateLimit" : $scope.torrent.downloadRateLimit}).
      success(function(data,status,headers,config){
        console.log("huzzah, changing setting succeeded");
      }).
      error(function(data,status,headers,config){
        $scope.errors.push(data);
      });   
  }

}

/* Controller for the config view */
function ConfigCtrl($scope, $timeout, $http) {
  $scope.deleteError = function(err){
    genericDeleteError($scope, err);
  }

  $http.get("/global_settings").
    success(function(data,status,headers,config){
      $scope.globalSettings = data;
    }).
    error(function(data,status,headers,config){
      $scope.globalSettings = {};
      $scope.errors.push(data);
    });

  $scope.applySettings = function(){
    $http.post("/global_settings", $scope.globalSettings).
      success(function(data,status,headers,config){
        console.log("huzzah, saving settings succeeded");
      }).
      error(function(data,status,headers,config){
        $scope.errors.push(data);
      });
  }
}

/* Controller used for login */
function LoginCtrl($scope, $window, $http) {
  $scope.errors = [];
  $scope.login = null;
  $scope.password = null;

  $scope.doLogin = function(){
    $http.post("/login", {"login": $scope.login, "password" : $scope.password}).
      success(function(data,status,headers,config){
        $window.location.href = '/';
      }).
      error(function(data,status,headers,config){
        $scope.errors.push(data);
      });   
  }

  $scope.doLogout = function(){
    $http.post("/logout").
      success(function(data,status,headers,config){
        $window.location.href = '/';
      }).
      error(function(data,status,headers,config){
        $window.location.href = '/';
      });   
  }

  $scope.deleteRootscopeError = function(err){}
  $scope.deleteError = function(err){
    genericDeleteError($scope, err);
  }
}

var torrentPropsNotToUpdate = { 'downloadRateLimit': 1 };

/* Helper used to update the $scope's list of torrent data shown in the table 
   from the full data retrieved from the server */
function updateTableTorrentData($scope) {
  if ( ! $scope.torrents )
    return;

  if ( ! $scope.torrentsForTable ) {
    $scope.torrentsForTable = {};
  }
  
  for (var key in $scope.torrents) {
    if ($scope.torrents.hasOwnProperty(key)) {
      torrent = $scope.torrents[key];
      if ( ! (key in $scope.torrentsForTable)) {
        // New entry
        $scope.torrentsForTable[key] = clone(torrent);
      }
      else {
        // Update entry if needed
        existing = $scope.torrentsForTable[key];
        for (var prop in torrent) {
          if (torrent.hasOwnProperty(prop)) {
            if (existing[prop] != torrent[prop] && !torrentPropsNotToUpdate[prop])
              existing[prop] = torrent[prop];
          }
        }
      }
    }
  }

  var toDelete = [];
  for (var key in $scope.torrentsForTable) {
    if ( ! (key in $scope.torrents)){
      // This torrent has been deleted server-side
      toDelete.push(key);
    }   
  }
  for(var i = 0; i < toDelete.length; i++) {
    delete $scope.torrentsForTable[toDelete[i]];
  }

  // Set up the current page
  updatePages($scope);
}

function updatePages($scope) {
  // Set up the current page
  var pageSize = 5;
  if( ! $scope.currentPageIndex ) {
    $scope.currentPageIndex = 0;
  }
  $scope.torrentsList = [];
  for (var key in $scope.torrentsForTable) {
    $scope.torrentsList.push($scope.torrentsForTable[key]);
  }
  var pageStartIndex = $scope.currentPageIndex * pageSize;
  var pageEndIndex = ($scope.currentPageIndex+1) * pageSize;
  $scope.currentPage = $scope.torrentsList.slice(pageStartIndex, pageEndIndex);
  $scope.totalPages = Math.floor(($scope.torrentsList.length - 1) / pageSize + 1);

  if( ! $scope.pagesInfo || $scope.pagesInfo.length != $scope.totalPages ) {
    updatePagesInfo($scope);
  }
}

function updatePagesInfo($scope) {
  $scope.pagesInfo = [];
  for(var i = 0; i < $scope.totalPages; i++){
    var style = (i == $scope.currentPageIndex ? "active" : "");
    $scope.pagesInfo.push({"number": i+1, "style": style});
  }
}

function clone(obj) {
  result = {};
  for (var prop in obj) {
    if (obj.hasOwnProperty(prop)) {
      result[prop] = obj[prop];
    }
  }
  return result;
}

function genericDeleteError($scope, err) {
  for(var i = 0; i < $scope.errors.length; i++) {
    if ( $scope.errors[i] == err ) {
      $scope.errors.splice(i,1);
      break;
    }
  }
  $scope.deleteRootscopeError(err);
}

/*********** IFRAME AJAX UPLOAD *************/

var iframeUploadResultMessages = [];

function getFrameByName(name) {
  for (var i = 0; i < frames.length; i++)
    if (frames[i].name == name)
      return frames[i];
        
  return null;
}

function handleIframeLoad(frameName)
{
  var frame = getFrameByName(frameName);
  if ( frame != null )
  {
    result = frame.document.getElementsByTagName("body")[0].innerHTML;
          
    // The form's onload handler gets called when the main page is first loaded as well.
    // We detect this condition by checking if the iframes contents are not empty.
    if ( result.length > 0 ){
      if ( iframeUploadResultMessages.length < 10 ){
        iframeUploadResultMessages.push(result);
      }
    }
  }
}
