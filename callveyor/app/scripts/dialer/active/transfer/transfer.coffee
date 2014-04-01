'use strict'

transfer = angular.module('callveyor.dialer.active.transfer', [])

transfer.config(['$stateProvider', ($stateProvider) ->
  $stateProvider.state('dialer.active.transfer', {
    abstract: true
    views:
      transferPanel:
        templateUrl: '/scripts/dialer/active/transfer/panel.tpl.html'
        controller: 'TransferPanelCtrl'
  })
  $stateProvider.state('dialer.active.transfer.selected', {
    views:
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
  })
  # ideally the {reload} option or fn would work but there seems to be a bug:
  # http://angular-ui.github.io/ui-router/site/#/api/ui.router.state.$state
  # https://github.com/angular-ui/ui-router/issues/582
  $stateProvider.state('dialer.active.transfer.reselect', {
    views:
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/selected/buttons.tpl.html'
        controller: 'TransferButtonCtrl.selected'
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
  })
  $stateProvider.state('dialer.active.transfer.conference', {
    views:
      transferInfo:
        templateUrl: '/scripts/dialer/active/transfer/info.tpl.html'
        controller: 'TransferInfoCtrl'
      transferButtons:
        templateUrl: '/scripts/dialer/active/transfer/conference/buttons.tpl.html'
        controller: 'TransferButtonCtrl.conference'
  })
])

transfer.controller('TransferPanelCtrl', [
  '$rootScope', '$scope', '$cacheFactory',
  ($rootScope,   $scope,   $cacheFactory) ->
    console.log 'TransferPanelCtrl'

    $rootScope.transferStatus = 'Ready to dial...'
])

transfer.controller('TransferInfoCtrl', [
  '$scope', '$cacheFactory',
  ($scope,   $cacheFactory) ->
    console.log 'TransferInfoCtrl'

    cache = $cacheFactory.get('transfer')
    transfer = cache.get('selected')
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.selected', [
  '$rootScope', '$scope', '$state', '$filter', '$cacheFactory', 'idDialerService', 'usSpinnerService', 'caller'
  ($rootScope,   $scope,   $state,   $filter,   $cacheFactory,   idDialerService,  usSpinnerService,    caller) ->
    console.log 'TransferButtonCtrl.selected', $cacheFactory.get('transfer').info()

    transfer = {}
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    transfer_type = transfer.cache.get('selected').transfer_type
    isWarmTransfer = -> transfer_type == 'warm'

    transfer.dial = ->
      console.log 'dial', $scope
      $rootScope.transferStatus = 'Dialing...'
      usSpinnerService.spin('transfer-spinner')
      p = idDialerService.dial()
      s = (o) ->
        console.log 'dial success', o
        if isWarmTransfer()
          $state.go('dialer.active.transfer.conference') # triggered from pusher event for warm transfers
        else
          $state.go('dialer.wrap')
      e = (r) -> console.log 'error', r
      c = (r) -> console.log 'notify', r
      p.then(s,e,c)

    transfer.cancel = ->
      console.log 'cancel'
      @cache.remove('selected')
      $state.go('dialer.active')

    console.log 'rootScope', $rootScope
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $rootScope.rootTransferCollapse = false
    console.log 'collapse before', $rootScope.rootTransferCollapse
    $scope.transfer = transfer
])

transfer.controller('TransferButtonCtrl.conference', [
  '$rootScope', '$scope', '$state', '$cacheFactory', 'idDialerService', 'usSpinnerService'
  ($rootScope,   $scope,   $state,   $cacheFactory,   idDialerService,   usSpinnerService) ->
    console.log 'TransferButtonCtrl.conference'

    transfer = {}
    transfer.cache = $cacheFactory.get('transfer') || $cacheFactory('transfer')
    usSpinnerService.stop('transfer-spinner')
    $rootScope.transferStatus = 'Transfer on call'
    transfer.hangup = ->
      console.log 'transfer.hangup'
      p = $state.go('dialer.active')
      s = (o) -> console.log 'success', o
      e = (r) -> console.log 'error', e
      c = (n) -> console.log 'notify', n
      p.then(s,e,c)

    $scope.transfer = transfer
])