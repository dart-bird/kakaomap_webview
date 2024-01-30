import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kakaomap_webview/src/kakao_figure.dart';
import 'package:kakaomap_webview/src/kakaomap_type.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class KakaoMapView extends StatefulWidget {
  KakaoMapView({
    required this.width,
    required this.height,
    required this.kakaoMapKey,
    required this.lat,
    required this.lng,
    this.zoomLevel = 3,
    this.overlayText,
    this.customOverlayStyle,
    this.customOverlay,
    this.polygon,
    this.polyline,
    this.showZoomControl = false,
    this.showMapTypeControl = false,
    this.onTapMarker,
    this.zoomChanged,
    this.cameraIdle,
    this.boundaryUpdate,
    this.markerImageURL = '',
    this.customScript,
    this.mapWidgetKey,
    this.draggableMarker = false,
    this.mapType,
    this.onProgress,
    this.onPageFinished,
    this.onWebResourceError,
  });

  /// Map width. If width is wider than screen size, the map center can be changed
  final double width;

  /// Map height
  final double height;

  /// default zoom level : 3 (0 ~ 14)
  final int zoomLevel;

  /// center latitude
  final double lat;

  /// center longitude
  final double lng;

  /// Kakao map key javascript key
  final String kakaoMapKey;

  /// If it's true, zoomController will be enabled.
  final bool showZoomControl;

  /// If it's true, mapTypeController will be enabled. Normal map, Sky view are supported
  final bool showMapTypeControl;

  /// Set marker image. If it's null, default marker will be showing
  final String markerImageURL;

  /// TRAFFIC, ROADVIEW, TERRAIN, USE_DISTRICT, BICYCLE are supported.
  /// If null, type is default
  final MapType? mapType;

  /// Set marker draggable. Default is false
  final bool draggableMarker;

  /// Overlay text. If null, it won't be enabled.
  /// It must not be used with [customOverlay]
  final String? overlayText;

  /// Overlay style. You can customize your own overlay style
  final String? customOverlayStyle;

  /// Overlay text with other features.
  /// It must not be used with [overlayText]
  final String? customOverlay;

  /// Marker tap event
  final void Function(JavaScriptMessage)? onTapMarker;

  /// Zoom change event
  final void Function(JavaScriptMessage)? zoomChanged;

  /// When user stop moving camera, this event will occur
  final void Function(JavaScriptMessage)? cameraIdle;

  /// North East, South West lat, lang will be updated when the move event is occurred
  final void Function(JavaScriptMessage)? boundaryUpdate;

  /// [KakaoFigure] is required [KakaoFigure.path] to make polygon.
  /// If null, it won't be enabled
  final KakaoFigure? polygon;

  /// [KakaoFigure] is required [KakaoFigure.path] to make polyline.
  /// If null, it won't be enabled
  final KakaoFigure? polyline;

  /// This is used to make your own features.
  /// Only map size and center position is set.
  /// And other optional features won't work.
  /// such as Zoom, MapType, markerImage, onTapMarker.
  final String? customScript;

  /// When you want to use key for the widget to get some features.
  /// such as position, size, etc you can use this
  final GlobalKey? mapWidgetKey;

  /// You can use js code with controller.
  /// example)
  /// mapController.evaluateJavascript('map.setLevel(map.getLevel() + 1, {animate: true})');

  final void Function(int)? onProgress;
  final void Function(String url)? onPageFinished;
  final void Function(WebResourceError error)? onWebResourceError;

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> {
  WebViewController _webViewController = WebViewController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initLoad();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: widget.mapWidgetKey,
      height: widget.height,
      width: widget.width,
      child: WebViewWidget(
        controller: _webViewController,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
          Factory(() => EagerGestureRecognizer()),
        ].toSet(),
      ),
    );
  }

  void initLoad() async {
    _webViewController = WebViewController()
      ..clearCache()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (widget.onProgress != null) widget.onProgress!(progress);
          },
          onPageStarted: (String url) {
            debugPrint('[kakaomap_webview] : 카카오맵 로딩시작');
          },
          onPageFinished: (String url) {
            if (widget.onPageFinished != null) widget.onPageFinished!(url);
            debugPrint('[kakaomap_webview] : 카카오맵 로딩완료');
          },
          onWebResourceError: (WebResourceError error) {
            if (widget.onWebResourceError != null) widget.onWebResourceError!(error);
            debugPrint('[kakaomap_webview] : 카카오맵 로딩오류 (${error.toString()})');
          },
        ),
      )
      ..setOnConsoleMessage((message) {
        debugPrint('[kakaomap_webview] Console : ${message.message}');
      });
    for (var channel in _getChannels.entries) {
      await _webViewController.addJavaScriptChannel(channel.key, onMessageReceived: channel.value);
    }
    if (widget.customScript == null) {
      await _webViewController.loadRequest(Uri.dataFromString('''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8"/>
        
        <style>
          .label {margin-bottom: 96px;}
          .label * {display: inline-block;vertical-align: top;}
          .label .left {background: url("https://t1.daumcdn.net/localimg/localimages/07/2011/map/storeview/tip_l.png") no-repeat;display: inline-block;height: 24px;overflow: hidden;vertical-align: top;width: 7px;}
          .label .center {background: url(https://t1.daumcdn.net/localimg/localimages/07/2011/map/storeview/tip_bg.png) repeat-x;display: inline-block;height: 24px;font-size: 12px;line-height: 24px;}
          .label .right {background: url("https://t1.daumcdn.net/localimg/localimages/07/2011/map/storeview/tip_r.png") -1px 0  no-repeat;display: inline-block;height: 24px;overflow: hidden;width: 6px;}
        </style>
      </head>
      <body style="margin:0px;padding:0px;">
        <div id='map' style="width:100%;height:100%;min-width:${widget.width}px;min-height:${widget.height}px;"></div>
        <script type="text/javascript" src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=127b6faea9be798305c12eb499db1678"></script>
        <script>
          var container = document.getElementById('map');
          var options = {
            center: new kakao.maps.LatLng(${widget.lat}, ${widget.lng}),
            level: 3
          };
          var map = new kakao.maps.Map(container, options);

          let markerImage
		
          if(${widget.markerImageURL.isNotEmpty}){
            let imageSrc = '${widget.markerImageURL}'
            let imageSize = new kakao.maps.Size(64, 69)
            let imageOption = {offset: new kakao.maps.Point(27, 69)}
            markerImage = new kakao.maps.MarkerImage(imageSrc, imageSize, imageOption)
          } else {
            let imageSize = new kakao.maps.Size(64, 69)
            let imageOption = {offset: new kakao.maps.Point(27, 69)}
            markerImage = new kakao.maps.MarkerImage(imageSrc, imageSize, imageOption)
          }
          const markerPosition  = new kakao.maps.LatLng(${widget.lat}, ${widget.lng});
          
          const marker = new kakao.maps.Marker({
            position: markerPosition,
            ${widget.markerImageURL.isNotEmpty ? 'image: markerImage' : ''}
          });
          
          marker.setMap(map);

          if(${widget.overlayText != null}){
            const content = '<div class ="label"><span class="left"></span><span class="center">${widget.overlayText}</span><span class="right"></span></div>';
        
            const overlayPosition = new kakao.maps.LatLng(${widget.lat}, ${widget.lng});  
        
            const customOverlay = new kakao.maps.CustomOverlay({
                map: map,
                position: overlayPosition,
                content: content,
                yAnchor: 0.8
            });
          } else if(${widget.customOverlay != null}){
            ${widget.customOverlay}
          }
          
          if(${widget.onTapMarker != null}){
            kakao.maps.event.addListener(marker, 'click', function(){
              onTapMarker.postMessage('marker is tapped');
            });
          }
          
          if(${widget.zoomChanged != null}){
            kakao.maps.event.addListener(map, 'zoom_changed', function() {        
              const level = map.getLevel();
              zoomChanged.postMessage(level.toString());
            });
          }
          
          if(${widget.cameraIdle != null}){
            kakao.maps.event.addListener(map, 'dragend', function() {        
              const latlng = map.getCenter();
              
              const idleLatLng = {
                lat: latlng.getLat(),
                lng: latlng.getLng()
              }
              
              cameraIdle.postMessage(JSON.stringify(idleLatLng));
            });
          }
          
          if(${widget.boundaryUpdate != null}){
            kakao.maps.event.addListener(map, 'bounds_changed', function() {  
              const bounds = map.getBounds();
          
              const neLatlng = bounds.getNorthEast();
              
              const swLatlng = bounds.getSouthWest();
              
              const boundary = {
                ne: {
                  lat: neLatlng.getLat(),
                  lng: neLatlng.getLng()
                },
                sw: {
                  lat: swLatlng.getLat(),
                  lng: swLatlng.getLng()
                }
              }
              
              boundaryUpdate.postMessage(JSON.stringify(boundary));
            });
          }
          
          if(${widget.showZoomControl}){
            const zoomControl = new kakao.maps.ZoomControl();
            map.addControl(zoomControl, kakao.maps.ControlPosition.RIGHT);
          }
          
          if(${widget.showMapTypeControl}){
            const mapTypeControl = new kakao.maps.MapTypeControl();
            map.addControl(mapTypeControl, kakao.maps.ControlPosition.TOPRIGHT);
          }
          
          if(${widget.mapType != null}){
            const changeMapType = ${widget.mapType?.getType};
            
            map.addOverlayMapTypeId(changeMapType);
          }
          
          marker.setDraggable(${widget.draggableMarker}); 
          
          if(${widget.polygon != null}){
            const polygon = new kakao.maps.Polygon({
              map: map,
              path: [${widget.polygon?.getPath}],
              strokeWeight: ${widget.polygon?.strokeWeight},
              strokeColor: ${widget.polygon?.getStrokeColor},
              strokeOpacity: ${widget.polygon?.strokeColorOpacity},
              strokeStyle: '${widget.polygon?.strokeStyle.name}',
              fillColor: ${widget.polygon?.getPolygonColor},
              fillOpacity: ${widget.polygon?.polygonColorOpacity} 
            });
          }
          
          if(${widget.polyline != null}){
            const polyline = new kakao.maps.Polyline({
              map: map,
              path: [${widget.polyline?.getPath}],
              strokeWeight: ${widget.polyline?.strokeWeight},
              strokeColor: ${widget.polyline?.getStrokeColor},
              strokeOpacity: ${widget.polyline?.strokeColorOpacity},
              strokeStyle: '${widget.polyline?.strokeStyle.name}'
            });
          }
        </script>
      </body>
      </html>''', mimeType: 'text/html', encoding: utf8));
    } else {
      await _webViewController.loadRequest(Uri.dataFromString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=yes\'>
            <script type="text/javascript" src='https://dapi.kakao.com/v2/maps/sdk.js?autoload=true&appkey=${widget.kakaoMapKey}'></script>
        </head>
        <body style="padding:0; margin:0;">
          <div id='map' style="width:100%;height:100%;min-width:$widget.width}px;min-height:${widget.height}px;"></div>
          <script>
            const container = document.getElementById('map');
            const options = {
              center: new kakao.maps.LatLng(${widget.lat}, ${widget.lng}),
              level: $widget.zoomLevel
            };
            const map = new kakao.maps.Map(container, options);
            ${widget.customScript}
          </script>
        </body>
        </html>
    ''', mimeType: 'text/html', encoding: utf8));
    }
  }

  Map<String, void Function(JavaScriptMessage)> get _getChannels {
    Map<String, void Function(JavaScriptMessage)> channels = {};
    if (widget.onTapMarker != null) {
      channels['onTapMarker'] = widget.onTapMarker!;
    }

    if (widget.zoomChanged != null) {
      channels['zoomChanged'] = widget.zoomChanged!;
    }

    if (widget.cameraIdle != null) {
      channels['cameraIdle'] = widget.cameraIdle!;
    }

    if (widget.boundaryUpdate != null) {
      channels['boundaryUpdate'] = widget.boundaryUpdate!;
    }

    if (channels.isEmpty) {
      return {};
    }

    return channels;
  }
}
