(function() {
  function createMap(data, iconPath, iconRetinaPath) {
    latlng = get_all_latlongs(data.records);
    center_map = getCentroid(latlng);

    var map = L.map( 'map', {
      center: center_map,
      // center: [10.0, 5.0],
      minZoom: 1,
      zoom: 2,
      loadingControl: true
    });

    //listener, good source here: https://leafletjs.com/reference-1.3.0.html#map-zoomend
    map.on('zoomstart', function() {
        enable();
        document.getElementById("checkbx").checked = true;
    });

    L.tileLayer( 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
     attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
     subdomains: ['a','b','c']
    }).addTo( map );

    //----------------------------------------------------------------------------------------------------------------//for NavBar
    L.control.navbar().addTo(map);
    //----------------------------------------------------------------------------------------------------------------

    var myIcon = L.icon({
      iconUrl: iconPath,
      iconRetinaUrl: iconRetinaPath,
      iconSize: [29, 24],
      iconAnchor: [9, 21],
      popupAnchor: [0, -14]
    });

    // var markerClusters = L.markerClusterGroup();
    var markerClusters = L.markerClusterGroup({
        maxClusterRadius: 60
        /* working-sshhh, only if u want to customize
        ,
        iconCreateFunction: function(cluster) {
            return L.divIcon({ html: '<b>' + cluster.getChildCount() + '</b>' });
        }
        */
    });

    var markers = data.records;
    var latlng = [];
    for ( var i = 0; i < markers.length; ++i ) {
      pic = markers[i];
      var title = '<i>'+pic.b+'</i>';                                                                                                 //sciname
      var infoHtml = '<div class="info"><h3>' + title + '</h3>';

      if(pic.l) {
        if (!pic.l.toLowerCase().startsWith('http://')) {
          infoHtml += '<div class="info-body"><img src="' + pic.l + '" class="info-img"/></div><br/>'; //pic_url (http won't display in Chrome etc., https will)
        } else {
          infoHtml += 'Image available at source<br/>';
        }
      }

      if(pic.a) {infoHtml += 'Catalog number: ' + pic.a + '<br/>';}                                                                   //catalogNumber

      infoHtml += 'Source portal: <a href="http://www.gbif.org/occurrence/' + pic.g + '" target="_blank">GBIF record</a>' + '<br/>' + //gbifID
                  'Publisher: <a href="http://www.gbif.org/publisher/' + pic.d + '" target="_blank">' + pic.c + '</a><br/>' +         //publisher_id & publisher
                  'Dataset: <a href="http://www.gbif.org/dataset/' + pic.f + '" target="_blank">' + pic.e + '</a><br/>';              //dataset_id & dataset
      if(pic.j)   {infoHtml += 'Recorded by: ' + pic.j + '<br/>';}                                                                    //recordedBy
      if(pic.k) {infoHtml += 'Identified by: ' + pic.k + '<br/>';}                                                                    //identifiedBy
      if(pic.m) {infoHtml += 'Event date: ' + pic.m + '<br/>';}                                                                       //eventDate
      infoHtml += '</div>';

      var m = L.marker( [markers[i].h, markers[i].i], {icon: myIcon} )
                      .bindPopup( infoHtml );
      markerClusters.addLayer( m );
      latlng.push([markers[i].h, markers[i].i]); //add value to array latlng
    }
    map.addLayer( markerClusters );

    //----------------------------------------------------------------------------------------------------------------//for Cluster On/Off
    /* working but not perfect. Had a hard time changing the button icon programmatically
    var toggle = L.easyButton({
      id: 'eli',
      states: [{
        stateName: 'add-markers',
        icon: 'fa-map-marker',
        // icon: '<span class="star">&diamond;</span>',
        title: 'Cluster On',
        onClick: function(control) {
            disable();
            control.state('remove-markers');
        }
      }, {
        stateName: 'remove-markers',
        icon: 'fa-undo',
        // icon: '<span class="star">&olarr;</span>',
        title: 'Cluster Off',
        onClick: function(control) {
            enable();
            control.state('add-markers');
        }
      }]
    });
    toggle.addTo(map);
    */
    //----------------------------------------------------------------------------------------------------------------
    //for enable disable cluster
    function enable() {
        markerClusters.enableClustering();
    }
    function disable() {
        // alert("view port: "+getFeaturesInView());
        if(getFeaturesInView() <= 1000) {markerClusters.disableClustering();}
        else {
            alert("Cannot un-cluster. Too many points.");
            document.getElementById("checkbx").checked = true;
        }
    }
    function getFeaturesInView() { //https://stackoverflow.com/questions/22081680/get-a-list-of-markers-layers-within-current-map-bounds-in-leaflet
      var features = [];
      var i = 0;
      map.eachLayer( function(layer) {
        if(layer instanceof L.Marker) {
          if(map.getBounds().contains(layer.getLatLng())) {
            features.push(layer.feature);
            // alert(console.debug(layer));
            if(isNaN(layer._childCount)){i = i + 1;}
            else                        {i = i + layer._childCount;}
          }
        }
      });
      /* working OK - good debug
      alert("total latlongs = "+i);                 //total coordinates, lat longs
      alert("total markers = "+features.length);    //total no of markers e.g. dot icon + cluster icon
      */
      return i; //total coordinates (points) in current view
    }
    //---------------------------------------------------------------------------------------------------------------- from: http://webdevzoom.com/get-center-of-polygon-triangle-and-area-using-javascript-and-php/
    function getCentroid(coord)
    {
        var center = coord.reduce(function (x,y) {
            return [x[0] + y[0]/coord.length, x[1] + y[1]/coord.length] 
        }, [0,0])
        return center;
    }
    //----------------------------------------------------------------------------------------------------------------
    function get_all_latlongs(markers)
    {
        var latlng = [];
        for ( var i = 0; i < markers.length; ++i ) {
          latlng.push([markers[i].h, markers[i].i]); //add value to array latlng
        }
        return latlng;
    }
    //----------------------------------------------------------------------------------------------------------------
    // create the control
    var checkbx = L.control({position: 'topleft'});
    checkbx.onAdd = function (map) {
        var div = L.DomUtil.create('div', 'checkbx');
        div.innerHTML = '<form><input id="checkbx" type="checkbox" checked/>Cluster</form>'; 
        return div;
    };
    checkbx.addTo(map);
    // add the event handler
    function handleCommand() {
       // alert("Clicked, checked = " + this.checked);
       if(this.checked == true) enable();
       else disable();
    }
    document.getElementById ("checkbx").addEventListener ("click", handleCommand, false);
  }

  $(function() {
    var $map = $('#map')
      , iconPath = $map.data('iconPath')
      , iconRetinaPath = $map.data('iconRetinaPath')
      , dataPath = $map.data('mapDataPath')
      ;

    $.getJSON(dataPath, function(data) {
      createMap(data, iconPath, iconRetinaPath);
    });
  });
})();

