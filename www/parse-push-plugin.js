var serviceName = 'ParsePushPlugin';

function extend(a, b) {
  if (b) {
    var k = null;
    for (k in b) {a[k] = b[k];}
  }
  return a;
}

var ParsePushPlugin = {
  _eventKey: null,
  _onNotify: function(pn, pushAction){
    if(pushAction === 'OPEN'){
      //
      // trigger a callback when user click open a notification.
      // One usecase for this pertains a cordova app that is already running in the background.
      // Relaying a push OPEN action, allows the app to resume and use javascript to navigate
      // to a different screen.
      //
      this.trigger('openPN', pn);
    } else{
      //
      //an eventKey can be registered with the register() function to trigger
      //additional javascript callbacks when a notification is received.
      //This helps modularizes notification handling for different aspects
      //of your javascript app, e.g., receivePN:chat, receivePN:system, etc.
      //
      var base = 'receivePN';
      this.trigger(base, pn);
      if(this._eventKey && pn[this._eventKey]){
        this.trigger(base + ':' + pn[this._eventKey], pn);
      }
    }
  },

  // Initialize Parse and register device to receive push notifications
  // IOS ONLY: if appId or clientKey is not set, Parse will not be initialized.
  //   Use the "initialize" method prior to calling this function.
  // ANDROID ONLY: Sets up notification javascript callbacks
  // params
  //   appId      # parse appId
  //   clientKey  # parse clientKey
  register: function(params, successCb, errorCb) {
    _params = extend({ecb: serviceName + '._onNotify'}, params);
    this._eventKey = params.eventKey || null;

    cordova.exec(successCb, errorCb, serviceName, 'register', [_params]);
  },

  getInstallationId: function(successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'getInstallationId', []);
  },

  getInstallationObjectId: function(successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'getInstallationObjectId', []);
  },

  getSubscriptions: function(successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'getSubscriptions',[]);
  },

  subscribe: function(channel, successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'subscribe', [ channel ]);
  },

  unsubscribe: function(channel, successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'unsubscribe', [ channel ]);
  },

  // iOS only

  // options: appId, clientKey
  // Only initializes Parse. No further action is taken.

  initialize: function(params, successCb, errorCb){
    cordova.exec(successCb, errorCb, serviceName, 'initializeParse', [ params ]);
  },

  setBadge: function(badgeNumber, successCb, errorCb) {
    cordova.exec(successCb, errorCb, serviceName, 'setBadge', [ badgeNumber ]);
  }
};

if (window.Parse) {
  extend(ParsePushPlugin, Parse.Events);
}

//
// give ParsePushPlugin event handling capability so we can use it to trigger
// push notification onReceive events
module.exports = ParsePushPlugin;
