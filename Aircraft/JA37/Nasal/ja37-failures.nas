
var install_failures = func {
  # random failure code:
  
  if(getprop("sim/ja37/supported/old-custom-fails") == 1) {
    #print("installing old failures");

    var fail = { SERVICEABLE : 1, JAM : 2, ENGINE: 3};
    var type = { MTBF : 1, MCBF: 2 };
    var failure_root = "/sim/failure-manager";
    var prop = "/instrumentation/head-up-display";

    failures.breakHash[prop] = {
      type: type.MTBF, failure: fail.SERVICEABLE, desc: "Head up display"};

    var o = failures.breakHash[prop];
    var t = "/mtbf";
    props.globals.initNode(failure_root ~ prop ~ t, 0);
    props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

    prop = "/instrumentation/instrumentation-light";

    failures.breakHash[prop] = {
      type: type.MTBF, failure: fail.SERVICEABLE, desc: "Instrumentation light"};

    props.globals.initNode(failure_root ~ prop ~ t, 0);
    props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

    prop = "/fdm/jsbsim/fcs/canopy";

    failures.breakHash[prop] = {
      type: type.MTBF, failure: fail.SERVICEABLE, desc: "Canopy"};

    props.globals.initNode(failure_root ~ prop ~ t, 0);
    props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

    prop = "/instrumentation/radar";

    failures.breakHash[prop] = {
      type: type.MTBF, failure: fail.SERVICEABLE, desc: "Radar"};

    props.globals.initNode(failure_root ~ prop ~ t, 0);
    props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

    setprop("/sim/failure-manager/display-on-screen", 1);
    #setprop("/sim/failure-manager/global-mcbf-0", 0);
    #setprop("/sim/failure-manager/global-mcbf-500", 1);
    #setprop("/sim/failure-manager/global-mcbf", 500);
    #setprop("/sim/failure-manager/global-mtbf-0", 0);
    #setprop("/sim/failure-manager/global-mtbf-86400", 1);
    #setprop("/sim/failure-manager/global-mtbf", 86400);

    #failures.setAllMCBF(500);
    #failures.setAllMTBF(86400);

  } else {
    #print("installing new failures");
    # put in 3.2+ failure handling code here
    var _init = func {
        removelistener(lsnr);
        #_failmgr.init();

        # Load legacy failure modes for backwards compatibility
        #io.load_nasal(getprop("/sim/fg-root") ~
        #              "/Aircraft/Generic/Systems/compat_failure_modes.nas");

        install_new_failures();
    }

    var lsnr = setlistener("sim/signals/fdm-initialized", _init, 0, 0);
    }
}

var install_new_failures = func {
    #print("New failures being processed.");
    io.include("Aircraft/Generic/Systems/failures.nas");

    ##
    # Trigger object that will fire when aircraft air-speed is over
    # min, specified in knots. Probability of failing will
    # be 0% at min speed and 100% at max speed and beyond.
    # When the specified property is 0 there is zero chance of failing.
    var SpeedTrigger = {

        parents: [FailureMgr.Trigger],
        requires_polling: 1,

        new: func(min, max, prop) {
            if(min == nil or max == nil)
                die("SpeedTrigger.new: min and max must be specified");

            if(min >= max)
                die("SpeedTrigger.new: min must be less than max");

            if(min < 0 or max <= 0)
                die("SpeedTrigger.new: min must be positive or zero and max larger than zero");

            if(prop == nil or prop == "")
                die("SpeedTrigger.new: prop must be specified");

            var m = FailureMgr.Trigger.new();
            m.parents = [SpeedTrigger];
            m.params["min-speed-kt"] = min;
            m.params["max-speed-kt"] = max;
            m.params["property"] = prop;
            m._speed_prop = "/velocities/airspeed-kt";
            return m;
        },

        to_str: func {
            sprintf("Increasing probability of fails between %d and %d kt air-speed",
                int(me.params["min-speed-kt"]), int(me.params["max-speed-kt"]))
        },

        update: func {
            if(getprop(me.params["property"]) != 0) {
                var speed = getprop(me._speed_prop);
                var min = me.params["min-speed-kt"];
                var max = me.params["max-speed-kt"];
                var speed_d =  0;
                if(speed > min) {
                    speed_d = speed-min;
                    var delta_factor = 1/(max - min);
                    var factor = speed <= max ? delta_factor*speed_d : 1;
                    if(rand() < factor) {
                        return 1;
                    }
                }
            }
            return 0;
        }
    };


    ##
    # Returns an actuator object that will set a property at
    # a value when triggered.
    var set_value = func(path, value) {

        var default = getprop(path);

        return {
            parents: [FailureMgr.FailureActuator],
            set_failure_level: func(level) setprop(path, level > 0 ? value : default),
            get_failure_level: func { getprop(path) == default ? 0 : 1 }
        }
    }

    setprop("/sim/failure-manager/display-on-screen", 1);
    var failure_root = "/sim/failure-manager";



    #gear

    var prop = "gear/gear[0]/position-norm";
    var trigger_gear0 = SpeedTrigger.new(350, 500, prop);
    var actuator_gear0 = set_value("fdm/jsbsim/gear/unit[0]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear0", "Front gear locking mechanism", actuator_gear0);
    FailureMgr.set_trigger("controls/gear0", trigger_gear0);

    prop = "gear/gear[1]/position-norm";
    var trigger_gear1 = SpeedTrigger.new(350, 500, prop);
    var actuator_gear1 = set_value("fdm/jsbsim/gear/unit[1]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear1", "Left gear locking mechanism", actuator_gear1);
    FailureMgr.set_trigger("controls/gear1", trigger_gear1);

    prop = "gear/gear[2]/position-norm";
    var trigger_gear2 = SpeedTrigger.new(350, 500, prop);
    var actuator_gear2 = set_value("fdm/jsbsim/gear/unit[2]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear2", "Right gear locking mechanism", actuator_gear2);
    FailureMgr.set_trigger("controls/gear2", trigger_gear2);

#    var prop = "fdm/jsbsim/gear/gear-pos-norm";
#    var trigger_gear = SpeedTrigger.new(350, 550, prop);
    #var actuator_gear1 = set_readonly(prop);
    #FailureMgr.add_failure_mode("controls/gear1", "Left gear", actuator_gear1);
#    FailureMgr.set_trigger("controls/gear", trigger_gear);

    ## test stuff: ##

    #Canopy
#    var prop = "/fdm/jsbsim/fcs/canopy";
#    var actuator_canopy = set_unserviceable(prop);
#    var trigger_canopy = MtbfTrigger.new(60);

#    FailureMgr.add_failure_mode("canopy", "Canopy", actuator_canopy);
#    FailureMgr.set_trigger("canopy", trigger_canopy);


    # test of mcbf
#    prop = "fdm/jsbsim/fcs/rudder-pos-norm";
#    var trigger_rudder = McbfTrigger.new("surface-positions/rudder-pos-norm", 2000);
    #var actuator_rudder = set_readonly(prop);

    #FailureMgr.add_failure_mode("controls/flight/rudder", "Rudder", actuator_rudder);
#    FailureMgr.set_trigger("controls/flight/rudder", trigger_rudder);#replace

    #test of altitude
#    prop = "gear/gear[1]/position-norm";
#    var trigger_gear1 = AltitudeTrigger.new(5000, 10000);
#    var actuator_gear1 = set_readonly(prop);

#    FailureMgr.add_failure_mode("gear1", "Left gear", actuator_gear1);
#    FailureMgr.set_trigger("gear1", trigger_gear1);

    # test of timeout
#    prop = "gear/gear[2]/position-norm";
#    var trigger_gear2 = TimeoutTrigger.new(60);
#    var actuator_gear2 = set_readonly(prop);

#    FailureMgr.add_failure_mode("gear2", "Right gear", actuator_gear2);
#    FailureMgr.set_trigger("gear2", trigger_gear2);
    setprop("sim/ja37/failures/installed", 1);
}

var _init = func {
        removelistener(lsnr_s);
        install_failures();
    }

var lsnr_s = setlistener("sim/ja37/supported/initialized", _init, 0, 0);
