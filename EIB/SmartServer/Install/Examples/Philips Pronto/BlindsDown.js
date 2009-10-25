CentralLong.Reset();
moveFlag = false;

onRelease = function() {
  if( !moveFlag ) {
    CentralStep.Reset();
  }
}

onHoldInterval = 1000;
onHold = function() {
  moveFlag = true;
  onHold = null;
}
