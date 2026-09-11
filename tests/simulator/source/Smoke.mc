import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

class SmokeApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [new WatchUi.View()]; }
}

(:test)
function simulatorSmoke(logger as Test.Logger) as Boolean {
    logger.debug("SETUP_CONNECTIQ_SIMULATOR_SMOKE_EXECUTED");
    return true;
}
